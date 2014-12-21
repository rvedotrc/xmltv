#!/home/mbrainz/perl/bin/perl -dw
# vi: set ts=4 sw=4 :

use constant CACHE_ROOT => '/home/rachel/cvs/local/misc-dev/xmltv/.cache';

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

exit;

