################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

=head1 NAME

PythonInterpreter - An object which will run and store the output of
python code. 

=head1 DESCRIPTION

This runs python code in a safe environment.  The output of the code 
is stored for later use.  Code can be provided files and command line arguments
as described below. 

Options for the jail_code process are:  

=over

=item code

This  is a string containing the code to run.  If no code is supplied,
then the code to run must be in one of the `files` copied, and must be
named in the `argv` list.

=item files

This  is a list of pairs, each pair is a filename and a bytestring
of contents to write into that file.  These files will be created in the
temp directory and cleaned up automatically.  No subdirectories are
supported in the filename.

=item argv

This is a list of command-line arguments to supply.

=item stdin

This is a string, the data to provide as the stdin for the process.

=back

Outputs of the python script are stored in 

=over

=item stdout

stdout of the program, a string

=item stderr

stderr of the program, a string

=item status

exit status of the process: an int, 0 for success

=back

=cut

use strict;
use Inline::Python;

package Python::PythonInterpreter;

sub new {
  my $class = shift;
  my $pgpath = shift;
  my $code = shift // '';
  my %options = @_;

  my $self = {code => $code,
	      pgpath => $pgpath,
	      status => undef,
	      stdout => undef,
	      stderr => undef,
	     };

  bless $self, $class;

  return $self;
}

sub options {
  my $self = shift;
  my %options = @_;

  foreach my $key (keys %options) {
    $self->{$key} = $options{$key};
  }

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
					       '',
					       $self->{files} // '',
					       $self->{argv} // '',
					       $self->{stdin} // '',
					      );
  };
  warn($@) if $@;

  $self->status(Inline::Python::py_get_attr($output,"status"));
  $self->stdout(Inline::Python::py_get_attr($output,"stdout"));
  $self->stderr(Inline::Python::py_get_attr($output,"stderr"));
  
  return $self->status;
}

1;
