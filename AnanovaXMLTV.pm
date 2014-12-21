#!/usr/bin/perl -w
# vi: set ts=4 sw=4 :

use strict;

package AnanovaXMLTV;
$| = 1 if -t STDOUT;

# Instructions: http://bleb.org/tv/data/listings

use constant LISTINGS_PAGE => "http://bleb.org/tv/data/listings";
use constant CACHE_ROOT => '/home/rachel/cvs/local/xmltv/.cache';
use constant LOG_FILE => '/home/rachel/cvs/local/xmltv/.requestlog';

=pod

Syntax:

http://www.bleb.org/tv/data/listings?days=...&format=...&channels=...&file=...

days
    Range: -1 to 6, where -1 is yesterday, 0 is today etc.
    Syntax: n..m or a,b,c.
channels
    List of channels separated by commas.
    Available channels are: bbc1, bbc2, itv1, ch4, five, bbc1_scotland, bbc1_wales, bbc3, bbc4, bbc7, bbc_6music, bbc_news24, bbc_radio1, bbc_radio1_xtra, bbc_radio2, bbc_radio3, bbc_radio4, bbc_radio5_live, bbc_radio5_live_sports_extra, boomerang, bravo, british_eurosport, cartoon_network, cbbc, cbeebies, challenge, discovery, disney, e4, film_four, ftn, itv2, men_and_motors, mtv, nick_junior, nickelodeon, oneword, paramount, paramount2, scifi, sky_movies1, sky_movies2, sky_movies3, sky_movies4, sky_movies5, sky_movies6, sky_movies7, sky_movies8, sky_movies9, sky_movies_cinema, sky_movies_cinema2, sky_one, sky_one_mix, sky_sports1, sky_sports2, sky_sports3, sky_sports_xtra, tcm, uk_bright_ideas, uk_drama, uk_gold, uk_gold2, uk_history, uk_horizons, uk_style, vh1 
format
    bleb (default) for "bleb"-XML.
    XMLTV for XMLTV.
file
    Compression algorithm.
    zip (default) for Zip file.
    tgz for .tar.gz.
    tbz2 for .tar.bz2.
    gz for Gzip (single-file formats only, eg. XMLTV).
    bzip2 for Bzip2 (single-file formats only, eg. XMLTV).

=cut

use Storable qw( freeze thaw );
use Cache::File;
my $cache = do {
	# Suppress this: Name "Cache::RemovalStrategy::LRU::FIELDS" used only once
	local $^W;
	Cache::File->new(
		cache_root => CACHE_ROOT,
		default_expires => '7 days',
	);
};

my $sleep = $ENV{SLEEP};
$sleep = 3 unless defined $sleep and $sleep >= 2;

my $ua;
sub get_cached
{
	my ($class, $url) = @_;
	my $key = $url;

	my $c = $cache->get($key);
	return $c if $c;

	print "Requesting ".$url unless $AnanovaXMLTV::quiet;
	sleep $sleep;
	print " ..." unless $AnanovaXMLTV::quiet;

	use LWP::UserAgent;
	$ua ||= LWP::UserAgent->new(
		agent => "bleb fetcher - contact via http://rve.org.uk/ please",
	);

	use Time::HiRes qw( gettimeofday tv_interval );
	my @now = gettimeofday;

	my $req = HTTP::Request->new(GET => $url);
	my $resp = $ua->request($req);
	$c = ($resp->is_success ? $resp->content : undef);

	if (open(my $log, ">>".LOG_FILE))
	{
		printf $log "%s; T=%6.2f; R=%d; S=%06d; %s\n",
			scalar localtime,
			tv_interval(\@now),
			$resp->code,
			length($c||""),
			$url,
			;
		close $log;
	}

	print "\n" unless $AnanovaXMLTV::quiet;

	$cache->set($key, $c, "7 days");
	$c;
}

################################################################################
# Channel List
################################################################################

sub find_first_node(&$)
{
	my ($sub, $tree) = @_;
	my @q = $tree;
	while (@q)
	{
		my $e = shift @q;
		return $e if &$sub($e);
		unshift @q, $e->content_list
			if ref $e;
	}
	undef;
}

sub fetch_regions
{
	my $class = shift;
	(
		[ "1", "Dummy region" ],
	);
}

sub regions
{
	my $class = shift;

	my $c = $cache->get("regions");
	if (defined $c)
	{
		$c = thaw($c);
	} else {
		my @regions = $class->fetch_regions();
		$cache->set("regions", freeze(\@regions), "30 days");
		$c = \@regions;
	}
	@$c;
}

sub fetch_channels
{
	my ($class, $region) = @_;

	my $url = LISTINGS_PAGE;
	my $content = $class->get_cached($url);

	my ($list) = $content =~ /Available channels are: <tt>(.*?)<\/tt>/s
		or die "Couldn't find channel list in this content:\n$content\n";
	my @channels = split /\s*,\s*/, $list;

	@channels = map { [$_,$_] } @channels;

	@channels;
}

sub channels
{
	my ($class, $region) = @_;
	my $key = "channels" . ($region ? "-r$region" : "");
	
	my $c = $cache->get($key);
	if (defined $c)
	{
		$c = thaw($c);
	} else {
		my @channels = $class->fetch_channels($region);
		$cache->set($key, freeze(\@channels), "7 days");
		$c = \@channels;
	}
	@$c;
}

################################################################################
# Channel Day Listing
################################################################################

sub fetch_channel_day_listing
{
	my ($class, $channelid, $daycode) = @_;

	my $url = LISTINGS_PAGE . "?days=$daycode&channels=$channelid&format=XMLTV&file=bzip2";
	my $content = $class->get_cached($url);

	if ($content =~ /\ABZ/)
	{
		use File::Temp qw( tempfile );

		my $infh = tempfile();
		my $outfh = tempfile();
		print $infh $content;
		require IO::Handle;
		$infh->flush;

		my $pid = fork;
		unless ($pid)
		{
			seek($infh, 0, 0);
			open(STDIN, "<&".fileno($infh)) or die $!;
			open(STDOUT, ">&".fileno($outfh)) or die $!;
			exec "/usr/bin/bunzip2 -" or die $!;
		}

		close $infh;
		wait;

		seek($outfh, 0, 0);
		$content = do { local $/; <$outfh> };
	}

	$content;
}

sub channel_day_listing
{
	my ($class, $channelid, $y, $m, $d) = @_;
	$channelid =~ /^\w+$/ or die;

	use Date::Calc qw( Today Delta_Days check_date );
	check_date($y, $m, $d) or die;

	my @today = Today;
	my $offset = Delta_Days(@today, $y, $m, $d);
	($offset >= -1 and $offset <= 6)
		or die "Date out of range";

	my $date = sprintf "%04d-%02d-%02d", $y, $m, $d;
	my $key = "xml-$channelid-$date";
	my $content = $cache->get($key);
	if (not defined $content or 1)
	{
		$content = $class->fetch_channel_day_listing($channelid, $offset);
		# TODO check correct day fetched (might be wrong if near date
		# boundary)
		$cache->set($key, $content, "7 days");
	}

	$content;
}

sub xml_channel_day_listing
{
	my $self = shift;
	my $content = $self->channel_day_listing(@_);

	require XML::LibXML;
	my $x = XML::LibXML->new;
	my $doc = eval { $x->parse_string($content) };

	unless ($doc)
	{
		my $err = $@;
		open(my $fh, ">failed-xml-parse.log");
		use Data::Dumper;
		print { $fh } Data::Dumper->Dump([ \@_ ],[ '*_' ]);
		print $fh "The error was: [$err]\n";
		print $fh "The content follows.\n";
		print $fh $content;
		die "Failed to parse XML - saved to failed-xml-parse.log\n";
	}

	$doc;
}

1;
# eof AnanovaXMLTV.pm
