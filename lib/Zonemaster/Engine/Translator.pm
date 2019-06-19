package Zonemaster::Engine::Translator;

use version; our $VERSION = version->declare("v1.0.8");

use 5.014002;
use strict;
use warnings;

use Moose;
use Carp;
use Zonemaster::Engine;

use POSIX qw[setlocale LC_MESSAGES];

BEGIN {
    # Locale::TextDomain (<= 1.20) doesn't know about File::ShareDir so give a helping hand.
    # This is a hugely simplified version of the reference implementation located here:
    # https://metacpan.org/source/GUIDO/libintl-perl-1.21/lib/Locale/TextDomain.pm
    require File::ShareDir;
    require Locale::TextDomain;
    my $share = File::ShareDir::dist_dir( 'Zonemaster-Engine' );
    Locale::TextDomain->import( 'Zonemaster-Engine', "$share/locale" );
}

has 'locale' => ( is => 'rw', isa => 'Str' );
has 'data'   => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_load_data' );

###
### Builder Methods
###

sub BUILD {
    my ( $self ) = @_;

    my $locale = $self->{locale} // _get_locale();
    $self->locale( $locale );

    return $self;
}

# Get the program's underlying LC_MESSAGES.
#
# Side effect: Updates the program's underlying LC_MESSAGES to the returned
# value.
sub _get_locale {
    my $locale = setlocale( LC_MESSAGES, "" );

    # C locale is not an option since our msgid and msgstr strings are sometimes
    # different in C and en_US.UTF-8.
    if ( $locale eq 'C' ) {
        $locale = 'en_US.UTF-8';
    }

    return $locale;
}

sub _load_data {
    my %data;

    $data{SYSTEM} = _system_translation();
    foreach my $mod ( 'Basic', Zonemaster::Engine->modules ) {
        my $module = 'Zonemaster::Engine::Test::' . $mod;
        $data{ uc( $mod ) } = $module->translation();
    }

    return \%data;
}

###
### Method modifiers
###

after 'locale' => sub {
    my ( $self ) = @_;

    setlocale( LC_MESSAGES, $self->{locale} );
};

###
### Working methods
###

sub to_string {
    my ( $self, $entry ) = @_;

    return sprintf( "%7.2f %-9s %s", $entry->timestamp, $entry->level, $self->translate_tag( $entry ) );
}

sub translate_tag {
    my ( $self, $entry ) = @_;

    my $string = $self->data->{ $entry->module }{ $entry->tag };

    if ( not $string ) {
        return $entry->string;
    }

    # Partial workaround for FreeBSD 11. It works once, but then translation
    # gets stuck on that locale.
    local $ENV{LC_ALL} = $self->{locale};

    return __x( $string, %{ $entry->printable_args } );
}

sub _system_translation {
    return {
        "CANNOT_CONTINUE"               => "Not enough data about {zone} was found to be able to run tests.",
        "PROFILE_FILE"                  => "Profile was read from {name}.",
        "DEPENDENCY_VERSION"            => "Using prerequisite module {name} version {version}.",
        "GLOBAL_VERSION"                => "Using version {version} of the Zonemaster engine.",
        "LOGGER_CALLBACK_ERROR"         => "Logger callback died with error: {exception}",
        "LOOKUP_ERROR"                  => "DNS query to {ns} for {name}/{type}/{class} failed with error: {message}",
        "MODULE_ERROR"                  => "Fatal error in {module}: {msg}",
        "MODULE_VERSION"                => "Using module {module} version {version}.",
        "MODULE_END"                    => "Module {module} finished running.",
        "NO_NETWORK"                    => "Both IPv4 and IPv6 are disabled.",
        "POLICY_DISABLED"               => "The module {name} was disabled by the policy.",
        "UNKNOWN_METHOD"                => "Request to run unknown method {method} in module {module}.",
        "UNKNOWN_MODULE"                => "Request to run {method} in unknown module {module}. Known modules: {known}.",
        "SKIP_IPV4_DISABLED"            => "IPv4 is disabled, not sending query to {ns}.",
        "SKIP_IPV6_DISABLED"            => "IPv6 is disabled, not sending query to {ns}.",
        "FAKE_DELEGATION"               => "Followed a fake delegation.",
        "ADDED_FAKE_DELEGATION"         => "Added a fake delegation for domain {domain} to name server {ns}.",
        "FAKE_DELEGATION_TO_SELF"       => "Name server {ns} not adding fake delegation for domain {domain} to itself.",
        "FAKE_DELEGATION_IN_ZONE_NO_IP" => "The fake delegation of domain {domain} includes an in-zone name server {ns} without mandatory glue (without IP address).",
        "FAKE_DELEGATION_NO_IP"         => "The fake delegation of domain {domain} includes a name server {ns} that cannot be resolved to any IP address.",
        "PACKET_BIG"                    => "Packet size ({size}) exceeds common maximum size of {maxsize} bytes (try with \"{command}\").",
    };
} ## end sub _system_translation

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Zonemaster::Engine::Translator - translation support for Zonemaster

=head1 SYNOPSIS

    my $trans = Zonemaster::Engine::Translator->new({ locale => 'sv_SE.UTF-8' });
    say $trans->to_string($entry);

A side effect of constructing an object of this class is that the program's
underlying locale for message catalogs (a.k.a. LC_MESSAGES) is updated.

It does not make sense to create more than one object of this class because of
the globally stateful nature of the locale attribute.

=head1 ATTRIBUTES

=over

=item locale

The locale that should be used to find translation data. If not
explicitly provided, defaults to (in order) the contents of the
environment variable LANG, LC_ALL, LC_MESSAGES or, if none of them are
set, to C<en_US.UTF-8>.

Updating this attribute also causes an analogous update of the program's
underlying LC_MESSAGES.

=item data

A reference to a hash with translation data. This is unlikely to be useful to
end-users.

=back

=head1 METHODS

=over

=item to_string($entry)

Takes a L<Zonemaster::Engine::Logger::Entry> object as its argument and returns a translated string with the timestamp, level, message and arguments in the
entry.

=item translate_tag

Takes a L<Zonemaster::Engine::Logger::Entry> object as its argument and returns a translation of its tag and arguments.

=item BUILD

Internal method that's only mentioned here to placate L<Pod::Coverage>.

=back

=cut