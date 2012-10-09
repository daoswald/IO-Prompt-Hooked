
use strict;
use warnings;
use Test::More;
use Capture::Tiny;
use IO::Prompt::Hooked;
use constant EMPTY_STRING => q{};

our $TEST_INPUT;
our $TEST_MESSAGE;
our $TEST_DEFAULT;
our $TEST_RESULT;

# Override IO::Prompt::Tiny::prompt so that we don't need to capture input and
# output.  We're going to take the leap of faith that IO::Prompt::tiny already
# does what it should.  We only want to test the functionality we're layering
# on top of it.

{
  no warnings 'redefine';
  *IO::Prompt::Tiny::prompt = sub {
      my ( $message, $default ) = @_;
      $TEST_MESSAGE = $message;
      $TEST_DEFAULT = $default;
      my $input =
          length  $TEST_INPUT ? $TEST_INPUT
        : defined $default    ? $default
        :                       EMPTY_STRING;
      return $input;
  };
}

# Basic tests: Positional arguments.  Positional args should behave like
# IO::Prompt::Tiny, with no changes.

# Given a prompt message, a default, and known input, we get back the input.
$TEST_INPUT = 'Good day.';
is( prompt( 'Hello world.', 'Howdy' ),
    'Good day.', 'Positional params return input.' );

# Our positional $message parameter passed through to IO::Prompt::Tiny::prompt.
is( $TEST_MESSAGE, 'Hello world.',
    'Positional params pass the prompt message.' );

# Our positional default parameter passed through to IO::Prompt::Tiny::prompt.
is( $TEST_DEFAULT, 'Howdy', 'Positional params pass the default.' );

# If user just hits enter, use the default.
$TEST_INPUT = EMPTY_STRING;
is( prompt( 'Hello world.', 'Howdy' ), 'Howdy',
    'Positional params return the default.' );

# If user just hits enter, and there's no default, return an empty string.
is( prompt( 'Hello world.' ), EMPTY_STRING,
    'Positional params with no input and no default return an empty string.' );


# Test basic features using named parameters.

# Given a prompt message, a default, and known input, we get back the input.
$TEST_INPUT = 'Good day.';
is( prompt( message => 'Hello world.', default => 'Howdy' ),
    'Good day.', 'Named params return input.' );

# Our positional $message parameter passed through to IO::Prompt::Tiny::prompt.
is( $TEST_MESSAGE, 'Hello world.',
    'Named params pass the prompt message.' );

# Our positional default parameter passed through to IO::Prompt::Tiny::prompt.
is( $TEST_DEFAULT, 'Howdy', 'Named params pass the default.' );

# If user just hits enter, use the default.
$TEST_INPUT = EMPTY_STRING;
is( prompt( message => 'Hello world.', default => 'Howdy' ), 'Howdy',
    'Named params return the default.' );

# If user just hits enter, and there's no default, return an empty string.
is( prompt( message => 'Hello world.' ), EMPTY_STRING,
    'Named params with no input and no default return an empty string.' );


# message, default, tries, validate, error, bad_try, escape.

# Test failed validation.

{
  my $test_tries = 0;
  $TEST_RESULT = 0;
  $TEST_INPUT  = 'Invalid';
  is( prompt( message  => 'Hello',
              default  => 'world',
              tries    => 50,
              validate => sub{0},
              error    => sub{ $TEST_RESULT = 1; ++$test_tries; EMPTY_STRING; },
      ), undef, "Validation rejects bad input."
  );
  is( $TEST_MESSAGE, 'Hello', 'Named parameters pass the message properly.' );
  is( $TEST_DEFAULT, 'world', 'Named parameters pass the default properly.' );
  is( $test_tries > 0, 1, 'error subref called on failed attempts.' );
  is( $test_tries, 50, 'Stopped after proper number of attempts.' );
  is( $TEST_RESULT, 1, 'Error callback invoked.' );

}

$TEST_INPUT = "\t";
is( prompt( message  => 'Hello',
            default  => 'world',
            validate => sub{0},
            escape   => sub{ $_[0] =~ qr/\t/ },
    ), undef, 'Escape bypasses validation and returns undef.'
);

{
  $TEST_INPUT = 'Invalid';
  my $test_tries = 0;
  is( prompt( message  => 'Hello',
              validate => sub { $_[0] =~ m/^valid$/ },
              tries    => 5,
              error    => sub {
                ++$test_tries;
                IO::Prompt::Hooked::terminate_input();
              },
      ), undef, 'Invalid input rejected.'
  );
  is( $test_tries, 1, 'Error may break out of loop.' );
}

subtest 'Testing POD synopsis' => sub {

    my $input;

    $TEST_INPUT = 'n';

    # Prompt exactly like IO::Prompt::Tiny
    $input = prompt( 'Continue? (y/n)' );       # No default.
    is( $input, $TEST_INPUT,
        'Prompt exactly like IO::Prompt::Tiny (input given).' );

    $TEST_INPUT = EMPTY_STRING;
    $input = prompt( 'Continue? (y/n)', 'y' );  # Defaults to 'y'.
    is( $input, 'y',
    'Prompt exactly like IO::Prompt::Tiny (default accepted).' );

    $TEST_INPUT = 'y';
    # Prompt with validation.
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      validate => qr/^[yn]$/i,
      error    => 'Input must be either "y" or "n".',
    );
    is( $input, $TEST_INPUT, 'Input validates.' );

    # Limit number of attempts
    $TEST_INPUT = 'Invalid';
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      validate => qr/^[yn]$/i,
      tries    => 5,
      error    => sub {
        my( $raw, $tries ) = @_;
        return '';
      },
    );
    is( $input, undef, 'Rejected invalid input after 5 tries.' );

    # Validate with a callback.
    $TEST_INPUT = 'y';
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      validate => sub {
        my $raw = shift;
        return $raw =~ /^[yn]$/i;
      },
      error    => 'Input must be either "y" or "n".',
    );
    is( $input, $TEST_INPUT, 'Callback validated input.' );

    # Give user an escape sequence.
    $TEST_INPUT = 'A';
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      escape   => qr/^A$/,
      validate => qr/^[yn]$/i,
      error    => 'Input must be "y" or "n" ("A" to abort input.)',
    );
    is( $input, undef, 'Escape sequence aborted input.' );

    # Break out of allotted attempts early.
    my $test_tries = 0;
    $input = prompt(
      message  => 'Continue? (y/n)',
      default  => 'y',
      validate => qr/^[yn]$/i,
      tries    => 5,
      error    => sub {
        my( $raw, $tries ) = @_;
        if( $raw !~ m/^[yn]/ && $tries < 3 ) {
          IO::Prompt::Hooked::terminate_input();
        }
        $test_tries++;
        return '';
      }
    );
    is( $test_tries, 2, 'terminate_input() breaks out of loop early.' );
    
    done_testing();
};

done_testing();
