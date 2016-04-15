=head1 NAME

PythonInterpreter - An object which will run and print python code.  

=head1 DESCRIPTION

This runs and prints python code.  

=head1 SYNOPSIS

=pod

    Run code in a jailed subprocess.

    `command` is an abstract command ("python", "node", ...) that must have
    been configured using `configure`.

    `code` is a string containing the code to run.  If no code is supplied,
    then the code to run must be in one of the `files` copied, and must be
    named in the `argv` list.

    `files` is a list of file paths, they are all copied to the jailed
    directory.  Note that no check is made here that the files don't contain
    sensitive information.  The caller must somehow determine whether to allow
    the code access to the files.  Symlinks will be copied as symlinks.  If the
    linked-to file is not accessible to the sandbox, the symlink will be
    unreadable as well.

    `extra_files` is a list of pairs, each pair is a filename and a bytestring
    of contents to write into that file.  These files will be created in the
    temp directory and cleaned up automatically.  No subdirectories are
    supported in the filename.

    `argv` is the command-line arguments to supply.

    `stdin` is a string, the data to provide as the stdin for the process.

    `slug` is an arbitrary string, a description that's meaningful to the
    caller, that will be used in log messages.

    Return an object with:

        .stdout: stdout of the program, a string
        .stderr: stderr of the program, a string
        .status: exit status of the process: an int, 0 for success

=cut

use strict;
use Inline::Python;

package Python::PythonInterpreter;

sub new {
  my $class = shift;
  my $pgpath = shift;
  my $code = shift // '';

  my $self = {code => $code,
	      pgpath => $pgpath,
	      status => undef,
	      stdout => undef,
	      stderr => undef,
	     };

  bless $self, $class;

  return $self;
}

sub code {
  my $self = shift;

  if (@_) {
    $self->{code} = shift;
  } else {
    return $self->{code};
  }
}

sub status {
  my $self = shift;

  if (@_) {
    $self->{status} = shift;
  } else {
    return $self->{status};
  }
}

sub stdout {
  my $self = shift;

  if (@_) {
    $self->{stdout} = shift;
  } else {
    return $self->{stdout};
  }
}

sub stderr {
  my $self = shift;

  if (@_) {
    $self->{stderr} = shift;
  } else {
    return $self->{stderr};
  }
}

sub evaluate {
  my $self = shift;
  
  my $code = $self->code;
  my $output;

  my $pgpath = $self->{pgpath}."/Python";

  my $preamble = <<EOS;
import sys
sys.path.append('$pgpath')
import codejail.jail_code
codejail.jail_code.configure('python', '/wwsandbox/bin/python','sandbox')
EOS

  eval {
    Inline::Python::py_eval($preamble);
  };
  warn($@) if $@;

  eval {
    $output = Inline::Python::py_call_function('codejail.jail_code',
					       'jail_code',
					       'python',
					       $code,
					      );
  };
  warn($@) if $@;

  $self->status(Inline::Python::py_get_attr($output,"status"));
  $self->stdout(Inline::Python::py_get_attr($output,"stdout"));
  $self->stderr(Inline::Python::py_get_attr($output,"stderr"));
  
  return $self->status;
}

sub stdout_html {
  my $self = shift;
  return _convert_to_html($self->stdout);
}

sub stderr_html {
  my $self = shift;
  return _convert_to_html($self->stderr);
}

sub code_html {
  my $self = shift;
  return _convert_to_html($self->code);
}


sub _convert_to_html {
  shift;

  s/\n/<br>/g;
  s/^.*File "jailed_code"[\S ]*\n//s;
   
  return;
}

1;
