sub looking_for
{
	my ($i) = @_;

	$i->{'TITLE'} =~ m/\b$_\b/i and return $_
		for split /\n/, <<EOF;
15 Storeys High
Absolute Power
Armando
Facts and Fancies
Fifteen Storeys High
Fist of Fun
Four at the Store
Genius
Gorman
Harry Hill
Hitch-hiker
Hitchhiker
I'm Sorry I Haven't A Clue
Just a Minute
Little Britain
Mary Whitehouse Experience
Mighty Boosh
Monkey Dust
Newman & Baddiel
Newman and Baddiel
On The Hour
Q I
QI
Radio Active
Radio 9
Radio9
Radio Nine
Ross Noble
Smoking Room
The Goon Show
The Now Show
The Sunday Format
EOF

	$i->{'TITLE'} eq $_ and return $_
		for (
			"24",
			"Lost",
		);

	for (
		"Dave Gorman",
		"Armando Iannucci",
	) {
		return $_ if $i->{'SUBTITLE'} =~ /\b$_\b/i;
		return $_ if $i->{'DESC'} =~ /\b$_\b/i;
	}

	return undef;
}
