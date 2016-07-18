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

package Python::PythonInterpreter;

use strict;
use Cwd qw(getcwd);
use IPC::Run qw(run);

use constant MAX_OUTPUT => 10000;
use constant TIMEOUT => 2;
use constant NICE_LEVEL => '-2';
use constant SB_USER => 'sandbox';
use constant SB_PYTHON => '/wwsandbox/bin/python';
use constant SB_PYLINT => '/wwsandbox/bin/pylint';
use constant SB_PYLINTRC => '/wwsandbox/pylint.rc';
use constant JAILED_CODE => 'jailed_code';

sub new {
  my $class = shift;
  my $conf_variables = shift;
  my $code = shift // '';
  my %options = @_;

  my $self = {code => $code,
	      pgpath => $conf_variables->{pg_lib},
	      run_pylint => $conf_variables->{run_pylint},
	      status => undef,
	      stdout => undef,
	      stderr => undef,
	     };

  bless $self, $class;

  $self->options(%options);
  
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

sub files {
  my $self = shift;

  if (@_) {
    $self->{files} = shift;
  } else {
    return $self->{files};
  }
}

sub argv {
  my $self = shift;

  if (@_) {
    $self->{argv} = shift;
  } else {
    return $self->{argv};
  }
}

sub stdin {
  my $self = shift;

  if (@_) {
    $self->{stdin} = shift;
  } else {
    return $self->{stdin};
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


  # make temporary directory
  my $olddir = getcwd;
  chdir("/tmp");
  my $tmpdir = mk_tmp_dir();
    
  # create python file containing jailed code
  my $fh;
  open($fh, ">",JAILED_CODE);
  chmod(0444,$fh);
  print $fh $code;
  close($fh);

  # for each temporary file create the file and add content
  foreach my $ref (@{$self->{files}}) {
    open($fh, ">",$$ref[0]);
    chmod(0444,$fh);
    print $fh $$ref[1];
    close($fh);
  }  

  # build the command, adding any extra arguments
  my $cmd = ref($self->{argv}) eq "ARRAY"
    ? [@{$self->{argv}}] : [];

  unshift @$cmd, ("sudo", "-u", SB_USER,  "nice", NICE_LEVEL,
		  SB_PYTHON, JAILED_CODE);

  my $stdout;
  my $stderr;
  my $stdin = $self->{stdin};

  # run the command, passing in references to stdin,
  # stdout and stderr
  my $status = run_python($cmd,\$stdin,\$stdout,\$stderr);

  # truncate stdout/stderr so they aren't too long
  if (length($stdout) > MAX_OUTPUT) {
    $stdout = substr($stdout,0,MAX_OUTPUT).'.....';
  }

  if (length($stderr) > MAX_OUTPUT) {
    $stderr = substr($stderr,0,MAX_OUTPUT).'.....';
  }

  # set status and other variables.  Clean up temp directories
  $self->status($status);
  $self->stdout($stdout);
  $self->stderr($stderr);

  rm_tmp_dir($tmpdir,$olddir);
  
  return $self->status;
}

sub pylint {
  my $self = shift;
  my $code = shift // $self->code;
  my $output;

  # make a temporary directory
  my $olddir = getcwd;
  my $tmpdir = mk_tmp_dir();
  
  # create python file for jailed code
  my $fh;
  open($fh, ">",JAILED_CODE);
  chmod(0444, $fh);
  print $fh $code;
  close($fh);

  # create pylint command
  my $cmd = ["sudo", "-u", SB_USER, "nice", NICE_LEVEL, SB_PYLINT,
		   "--rcfile=".SB_PYLINTRC, JAILED_CODE];

  # run pylint command, passing in references for stdin
  # stdout stderr
  my $stdout;
  my $stderr;
  my $stdin;
     
  run_python($cmd,\$stdin,\$stdout,\$stderr);

  warn($stderr) if $stderr && $stderr !~ /Took Too Long/;

  rm_tmp_dir($tmpdir,$olddir);
  
  my $messages = $stdout;
  my $comment = '';

  if ($messages) {
    $messages =~ s/^.*\n//;
    my @elements = split(/@#/s,$messages);
    
    $comment = "<h4>Style Messages</h4>\n";
    $comment .= "<table class='table' style='font-family: Monaco, monospace'>\n";
    $comment .= "<tr><th>Category</th><th>Error Type</th><th>Object</th>";
    $comment .= "<th>Line</th><th>Message</th></tr>\n";
    
    for (my $i=0; $i+5 <= $#elements; $i += 6) {
      $elements[$i+1] = "<a href=\"http://pylint-messages.wikidot.com/messages:$elements[$i+5]\" target='ww_pylint'>$elements[$i+1]</a>";
      $elements[$i+4] =~ s/ /&nbsp;/g;
      $elements[$i+4] =~ s/\n/<br\>/g;
      
      $comment .= "<tr>";
      for (my $j=0; $j<5; $j++) {
	$comment .= "<td>$elements[$i+$j]</td>";
      }
      $comment .= "</tr>\n";
    }
    
    $comment .= "</table>\n";
  }
  
  return $comment;
}

sub run_python {
  my ($cmd, $r_stdin, $r_stdout, $r_stderr) = @_;

  my $status;

  eval {
    local $SIG{ALRM} = sub {
      system("sudo -u ".SB_USER." pkill -o python");
      die "Took Too Long";
    };

    alarm(TIMEOUT); 
    run $cmd, $r_stdin, $r_stdout, $r_stderr;
        
    $status = $? >> 8;
  };

  if ($@) {
    if ($@ =~ /Took Too Long/) {
      $$r_stderr = "Took Too Long";
    } else {
      warn($@);
    }
  }

  select STDOUT;
  
  return $status;
}

sub mk_tmp_dir {
  chdir("/tmp");
  my $tmpdir = 'codejail-';
  for (1 .. 6) {
    $tmpdir .= ('0'..'9','A'..'Z','a'..'z')[rand 60]
  }
  mkdir($tmpdir);
  chmod(0755,$tmpdir);
  chdir($tmpdir);
  return $tmpdir
}

sub rm_tmp_dir {
  my $tmpdir = shift;
  my $olddir = shift;

  unlink glob "'/tmp/$tmpdir/*'";
  rmdir "/tmp/$tmpdir";
  chdir $olddir;
}
1;
