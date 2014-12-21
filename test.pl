#!/home/mbrainz/perl/bin/perl -w
# vi: set ts=4 sw=4 :

use strict;

use AnanovaXMLTV;

my @c = AnanovaXMLTV->channels;
my %c = map { @$_ } @c;
my %r = reverse %c;
#use Data::Dumper;
#print Data::Dumper->Dump([ \%c, \%r ],[ '*c', '*r' ]);

my $bbc1 = $r{"bbc1"} or die;
use Date::Calc qw( Today );
my $xml = AnanovaXMLTV->xml_channel_day_listing($bbc1, Today);
use Data::Dumper;
print Data::Dumper->Dump([ $xml ],[ 'xml' ]);

my @chan = $xml->findnodes("/tv/channel");
for my $c (@chan)
{
	my $id = $c->getAttribute("id");
	my $name = $c->findvalue("./display-name");
	print "$id : $name\n";
}

for my $prog ($xml->findnodes("/tv/programme"))
{
	# ./@start, ./@stop = yyyymmddhhmmss ZZZ
	# ./@channel = a channel id
	# ./x-broadcast, ./x-programme ????
	# ./title [lang="en"] - text content.
	#   ./sub-title [@lang]
	# ./desc [lang="en"] - text content (multiple)
	# ./category [@lang, @x-code] text content (multiple)
	# ./subtitles [@type]
	# ./episode-num text content like ".7/8." or ".1234."
	# ./video, ./video/present, ./video/aspect
	# ./audio, ./audio/present, ./audio/stereo

	my $start = $prog->findvalue('./@start');
	my $stop = $prog->findvalue('./@stop');
	my $title = $prog->findvalue("./title");
	print "$start - $stop : $title\n";
}

# eof test.pl
