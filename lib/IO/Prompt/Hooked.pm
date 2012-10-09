#!/usr/bin/env perl
package IO::Prompt::Hooked;

use strict;
use warnings;
use Params::Smart;
use IO::Prompt::Tiny ();

our $VERSION = '0.01';

use parent 'Exporter';

our @EXPORT    = qw( prompt   );
our @EXPORT_OK = qw( terminate_input );

# Template for Params::Smart validation.
my @params = (
  {
    name      => 'message',
    required  => 0,
#    default   => '$',
  },
  {
    name      => 'default',
    required  => 0,
  },
  {
    name      => 'tries',
    required  => 0,
    name_only => 1,
    default   => -1,
  },
  {
    name      => 'validate',
    required  => 0,
    name_only => 1,
    default   => sub {1},
  },
  {
    name      => 'error',
    required  => 0,
    name_only => 1,
  },
  {
    name      => 'escape',
    required  => 0,
    name_only => 1,
    default   => sub {0},
  },
);

sub prompt {
  my @params = _unpack_prompt_params( @_ ); 
  return _hooked_prompt( @params );
}

sub terminate_input {
  no warnings 'exiting';
  last;
}

sub _unpack_prompt_params {
  my @args = ref $_[0] ? %{shift()} : @_;
  my %args = Params( @params )->args(@args);

  # 'validate' and 'escape' can be passed a regex object instead of a subref.
  for my $arg ( qw( validate escape ) ) {
    if( exists $args{$arg} && ref $args{$arg} eq 'Regexp' ) {
      my $regex = $args{$arg};
      $args{$arg} = sub { $_[0] =~ $regex; };
    }
  }
  if( exists $args{error} && ref $args{error} ne 'CODE' ) {
    my $message = $args{error};
    $args{error} = sub { $message };
  }
  return @args{ qw( message default tries validate error escape ) };
}

sub _hooked_prompt {
  my( $msg, $default, $tries, $validate_cb, $error_cb, $escape_cb )
    = @_;

  return $default
    if defined $tries && $tries == 0 && defined $default;

  while( $tries ) {

    my $raw = IO::Prompt::Tiny::prompt( $msg, $default );

    $tries--;

    last if $escape_cb->($raw, $tries);

    return $raw if $validate_cb->($raw, $tries);

    if ( my $error_msg = $error_cb->($raw, $tries) ) {
      print $error_msg;

    }
  }

  return;  # If we arrived here, no valid input accepted.
}

1;

__END__

=pod

=head1 IO::Prompt::Hooked

Simple prompts with validation hooks.

=head1 SYNOPSIS

    use IO::Prompt::Hooked;

    # Prompt exactly like IO::Prompt::Tiny
    $input = prompt( 'Continue? (y/n)' );       # No default.
    $input = prompt( 'Continue? (y/n)', 'y' );  # Defaults to 'y'.

    # Prompt with validation.
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      validate => qr/^[yn]$/i,
      error    => 'Input must be either "y" or "n".',
    );

    # Limit number of attempts
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      validate => qr/^[yn]$/i,
      tries    => 5,
      error    => sub {
        my( $raw, $tries ) = @_;
        return "'y' or 'n' only. You have $tries attempts remaining.";
      },
    );

    # Validate with a callback.
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      validate => sub {
        my $raw = shift;
        return $raw =~ /^[yn]$/i;
      },
      error    => 'Input must be either "y" or "n".',
    );

    # Give user an escape sequence.
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      escape   => qr/^A$/,
      validate => qr/^[yn]$/i,
      error    => 'Input must be "y" or "n" ("A" to abort input.)',
    );

    # Break out of allotted attempts early.
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      validate => qr/^[yn]$/i,
      tries    => 5,
      error    => sub {
        my( $raw, $tries ) = @_;
        if( $raw !~ m/^[yn]/ && $tries < 3 ) {
          print "You're not reading the instructions!  Input terminated\n";
          IO::Prompt::Hooked::terminate_input();
        }
        return "Must enter a single character, 'y' or 'n'";
      }
    );

=head1 DESCRIPTION

IO::Prompt::Tiny is a nice module to use for basic prompting.  It properly
detects interactive sessions, and since it's based on the C<prompt()> routine
from L<ExtUtils::MakeMaker>, it's highly portable.

But L<IO::Prompt::Tiny> is intentionally minimal.  L<IO::Prompt::Hooked> adds
simple validation, attempt limiting, and error handling to IO::Prompt::Tiny's
minimalism.  It does this by allowing you to supply simple Regexp objects for
validation, or subroutine callbacks if you need to get a little fancier.

"But we already have L<IO::Prompt> for non-trivial needs.", you
might be thinking.  And you're right.  But have you read its POD?  It's far from
being simple, and does have an imcompatibility that IO::Prompt::Tiny manages
to overcome.  IO::Prompt provides many options and controls.  IO::Prompt::Hooked
provides a few easy to use hooks.

=head1 EXPORTS

L<IO::Prompt::Hooked> exports C<prompt()>, and optionally C<terminate_input()>.

=head1 SUBROUTINES

=head2 C<prompt>

=head3 Just like IO::Prompt::Tiny

    my $input = prompt( 'Prompt message' );
    my $input = prompt( 'Prompt message', 'Default value' );

=head3 Or not... (named parameters)

    my $input = prompt(
      message  => 'Please enter an integer between 0 and 255 ("A" to abort)',
      default  => '0',
      tries    => 5,
      validate => sub {
        my $raw = shift;
        return $raw =~ /^[0-9]+$/ && $raw >= 0 && $raw <= 255;
      },
      escape   => qr/^A$/i,
      error    => sub {
        my( $raw, $tries ) = @_;
        return "Invalid input. You have $tries attempts remaining.";
      },
    );

=head3 Description of named parameters

=head4 C<message>

The message that will be displayed to the user ahead of the input cursor.

=head4 C<default>

An optional default value that will be displayed as C<[default]> to the user,
and that will be returned if the user hits enter without providing any input.

=head4 C<tries>

Useful only if input is being validated.  A positive number of attempts
permitted.  If C<tries> is set to zero, C<prompt> won't prompt, and will return
the default if one exists, or undef otherwise.  Setting C<tries> to a negative
number will facilitate monitoring the number of attempts within one of the
callback hooks without actually stopping at zero.

=head4 C<validate>

    validate => qr/^\w+$/
    validate => sub {
      my( $raw, $tries_remaining ) = @_;
      return $raw =~ m/^\w+$/
    }

C<validate> accepts either a C<Regexp> object (created via C<qr//>), or a
subroutine reference.  The regexp must match, or the sub must return true for
the input to be accepted.  Any false value will cause input to be rejected, and
the user will be prompted again unless C<tries> is set, and she's out of tries.

The sub callback will be invoked as
C<<$valiate_cb->( $raw_input, $tries_remaining) >>.  Thus, the sub you supply
has access to the raw (chomped) user input, as well as how many tries are
remaining.  Note: If C<tries> hasn't been explicitly set, it implicitly starts
out at -1 for the first attempt, and counts down, -2, -3, etc.  This can be
useful in monitoring how many attempts have been made even when no specific
limit has been set.

=head4 C<error>

The C<error> field accepts a string that will be printed to notify the user
of invalid input, or a subroutine reference that should return a string.  The
sub-ref callback has access to the raw input and number of tries remaining just
like the validate callback.  The purpose of the C<error> field is to generate
a warning message.  But by supplying a subref, it can be abused as you see fit.
The callback will only be invoked if the user input fails to validate.

=head4 C<escape>

The C<escape> field accepts a regular expression object, or a subroutine
reference to be used as a callback.  If the regex matches, or the callback
returns true, C<prompt()> returns C<undef> immediately.

Again, the escape callback is invoked as C<< $escape_cb->( $raw, $tries ) >>.
The primary use is to give the user an escape sequence.  But again, the sub
callback opens the doors to much flexibility.

=head2 C<terminate_input>

Insert a call to C<IO::Prompt::Hooked::terminate_input()> inside of any callback
to force C<prompt()> to return C<undef> immediately.  This is essentially a
means of placing "C<last>" into your callback without generating a warning about
returning from a subroutine via C<last>.  It's a dirty trick, but could prove
useful.

