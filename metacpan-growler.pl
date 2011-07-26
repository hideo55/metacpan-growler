#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/extlib/lib/perl5";

use Cocoa::Growl;
use Cocoa::EventLoop;
use AnyEvent;
use AnyEvent::HTTP;
use JSON;
use Data::MessagePack;
use Cache::LRU;
use Encode;

our $VERSION = '0.02';

my $app_name   = 'MetaCPAN Growler';
my $app_domain = 'org.github.hideo55.metacpangrowler';

my $search_uri = 'http://api.metacpan.org/v0/release/_search';
my $post_data  = JSON::encode_json(
	{   'size' => 20,
		'from' => 0,
		'sort' => [ { 'date' => { 'order' => 'desc', }, }, ],
		'query'  => { match_all => {} },
		'fields' => [qw(name author id)],
	}
);
my $author_api = 'http://api.metacpan.org/v0/author';

Cocoa::Growl::growl_register(
	app           => $app_name,
	icon          => 'http://metacpan.org/favicon.ico',
	notifications => [ 'Update', 'Error' ],
	defaults      => [ 'Update', 'Error' ],
);

my %options = ( interval => 300, maxGrowls => 10, cacheSize => 100, );
get_preferences( \%options, "interval", "maxGrowls", "cacheSize" );

my $Cache = Cache::LRU->new( size => $options{'cacheSize'} );

my $t;
$t = AnyEvent->timer(
	after    => 0,
	interval => $options{'interval'},
	cb       => sub {
		get_metacpan_info( $options{'maxGrowls'} );
	}
);

AE::cv->recv;

my %Seen;

sub get_metacpan_info {
	my $max_growls = shift;

	for my $uri ($search_uri) {

		http_post $uri, $post_data,
			headers    => {},
			persistent => 0,
			sub {
			my $mod_info
				= $_[1]->{Status} == 200
				? eval { JSON::decode_json( $_[0] ) }
				: undef;

			unless ($mod_info) {

				Cocoa::Growl::growl_notify(
					name        => 'Error',
					title       => $app_name,
					description => "Can't parse the metacpan response.",
				);
				return;
			}

			my @to_growl;
			for my $entry ( @{ $mod_info->{hits}{hits} } ) {
				my $id = $entry->{fields}{id};
				next if $Seen{$id}++;
				next
					if @to_growl >= $max_growls
				;    # not last, so that we can cache them in %Seen
				push @to_growl, $entry;
			}

			for my $entry (@to_growl) {
				my $author_id = $entry->{fields}{author};
				get_author(
					$author_id,
					sub {
						my $author = shift;
						$author->{name} ||= $author_id;
						my $title       = $author->{name};
						my $name        = $entry->{fields}{name};
						my $description = $name;
						$description = ' : ' . $entry->{fields}{abstract}
							if $entry->{fields}{abstract};
						my $icon
							= $author->{avatar} ? "$author->{avatar}" : q{};

						Cocoa::Growl::growl_notify(
							name        => 'Update',
							title       => encode_utf8($title),
							description => encode_utf8($description),
							icon        => $author->{avatar},
							on_click    => sub {
								my $link
									= "http://metacpan.org/release/${author_id}/${name}";
								system( "open", $link );
							},
						);
					}
				);
			}
		};
	}
}

sub get_preferences {
	my ( $opts, @keys ) = @_;

	for my $key (@keys) {
		my $value = read_preference($key);
		$opts->{$key} = $value if defined $value;
	}
}

sub read_preference {
	my $key = shift;

	no warnings 'once';
	open OLDERR, ">&STDERR";
	open STDERR, ">/dev/null";
	my $value = `defaults read $app_domain $key`;
	open STDERR, ">&OLDERR";

	return if $value eq '';
	chomp $value;
	return $value;
}

sub get_author {
	my ( $author, $cb ) = @_;

	if ( my $cache = $Cache->get($author) ) {
		$cb->( Data::MessagePack->unpack($cache) );
	}
	else {
		http_get "$author_api/$author", sub {
			if ( $_[1]->{Status} == 200 ) {
				my $content     = JSON::decode_json( $_[0] );
				my $author_info = {
					name   => $content->{name},
					avatar => $content->{gravatar_url},
				};
				$Cache->set(
					$author => Data::MessagePack->pack($author_info) );
				$cb->($author_info);
			}
			else {
				$cb->( {} );
			}
		};
	}

}

1;
__END__

=head1 NAME

metacpan-growler

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
