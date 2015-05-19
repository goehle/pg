######################################################################
##
##  Functions for creating tables of various kinds
##
##

my ($BCODE,
    $ECODE,
    $I,
    $II,
    $III,
    $IIII,
    );

sub _WCUCSmacros_init {}; # don't reload this file

main::PG_restricted_eval( <<'EOF');
$main::BCODE = BCODE();
$main::ECODE = ECODE();
$main::I = INDENT();
$main::II = IINDENT();
$main::III = IIINDENT();
$main::IIII = IIIINDENT();
EOF

$BCODE = BCODE();
$ECODE = ECODE();
$I = INDENT();
$II = IINDENT();
$III = IIINDENT();
$IIII = IIIINDENT();

sub BCODE { MODES(TeX => '\begin{verbatim} ',  Latex2HTML => '\begin{verbatim} ', HTML => '<CODE>'); };
sub ECODE { MODES( TeX => '\end{verbatim}', Latex2HTML =>  '\end{verbatim}',HTML =>  '</CODE>'); };
sub INDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;'); };
sub IINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };
sub IIINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };
sub IIIINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };

sub python_cmp {

    my $self = shift;
    my $ans = new AnswerEvaluator;

    $ans->ans_hash(
	type => "code",
	correct_ans => "Undefined",
	correct_value => $self,
	@_,
	);

    $ans->install_evaluator(sub { 			
	my $student = shift;
	my %response_options = @_;
	
	$student->{original_student_ans} = (defined $student->{original_student_ans})? $student->{original_student_ans} :'';
	
	$preamble = <<EOS;
import codejail.jail_code
codejail.jail_code.configure('python', '/wwsandbox/bin/python','sandbox')
EOS

        Inline::Python::py_eval($preamble);

	$answer_code = $student->{original_student_ans};

        # jail_code(command, code=None, files=None, extra_files=None, 
        #           argv=None, stdin=None)

	eval {
	    $output = Inline::Python::py_call_function('codejail.jail_code','jail_code','python',$answer_code);
	};
	
	WARN_MESSAGE($@) if $@;

	$stdout = $output->{stdout};
	$stderr = $output->{stderr};

	$stdout =~ s/\n/<br>/g;
	$stderr =~ s/^.*File "jailed_code"[\S ]*\n//s;

	my $ans_hash = new AnswerHash(
	    'score'=>"0",
	    'correct_ans'=>"Undefined",
	    'student_ans'=>'', #supresses output to original answer field
	    'original_student_ans' => $answer_value,
	    'type' => 'essay',
	    'ans_message'=> $stderr,
	    'preview_text_string'=> '',
	    'preview_latex_string'=> $stdout,
	    );

	return $ans_hash;
			    }
	);
    
    $ans->install_pre_filter('erase') if $self->{ans_name};
    
    return $ans;
}



1;
