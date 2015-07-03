######################################################################
##
##  Functions for creating tables of various kinds
##
##

my ($BCODE,
    $ECODE,
    $BPCODE,
    $EPCODE,
    $I,
    $II,
    $III,
    $IIII,
    );

sub _WCUCSmacros_init {
    loadMacros('text2PG.pl');   

    if (!$main::WCUCSHeaderSet) {
	main::HEADER_TEXT(<<'END_HEADER_TEXT');
	<script src="/webwork2_files/js/vendor/codeprettify/run_prettify.js" language="javascript"></script>
END_HEADER_TEXT

	$main::WCUCSHeaderSet = 1;
    }

}; # don't reload this file

main::PG_restricted_eval( <<'EOF');
$main::BPCODE = BPCODE();
$main::EPCODE = EPCODE();
$main::BCODE = BCODE();
$main::ECODE = ECODE();
$main::I = INDENT();
$main::II = IINDENT();
$main::III = IIINDENT();
$main::IIII = IIIINDENT();
EOF

$BPCODE = BPCODE();
$EPCODE = EPCODE();
$BCODE = BCODE();
$ECODE = ECODE();
$I = INDENT();
$II = IINDENT();
$III = IIINDENT();
$IIII = IIIINDENT();

sub BPCODE { MODES(TeX => '\begin{verbatim} ',  Latex2HTML => '\begin{verbatim} ', HTML => '<CODE class="prettyprint lang-python">'); };
sub EPCODE { MODES( TeX => '\end{verbatim}', Latex2HTML =>  '\end{verbatim}',HTML =>  '</CODE>'); };
sub BCODE { MODES(TeX => '\begin{verbatim} ',  Latex2HTML => '\begin{verbatim} ', HTML => '<CODE>'); };
sub ECODE { MODES( TeX => '\end{verbatim}', Latex2HTML =>  '\end{verbatim}',HTML =>  '</CODE>'); };
sub INDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;'); };
sub IINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };
sub IIINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };
sub IIIINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };

sub python_eval {

    $code = shift;

    $preamble = <<EOS;
import codejail.jail_code
codejail.jail_code.configure('python', '/wwsandbox/bin/python','sandbox')
EOS

    Inline::Python::py_eval($preamble);
    
    eval {
	$output = Inline::Python::py_call_function('codejail.jail_code','jail_code','python',$code);
    };
    
    WARN_MESSAGE($@) if $@;
    
    WARN_MESSAGE($output->{stderr}) if defined($output->{stderr});
    
    $stdout = $output->{stdout};
    $stderr = $output->{stderr};
    
    $stdout =~ s/\n/<br>/g;
    $stderr =~ s/^.*File "jailed_code"[\S ]*\n//s;
    
    return $stdout;
    
}

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
	    $output = Inline::Python::py_call_function('codejail.jail_code','jail_code','python',$answer_code,[],[['test','hithere']]);
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
	    'type' => 'text',
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

sub exact_str_cmp {
    my $correctAnswer = shift @_;
    $correctAnswer = '' unless defined($correctAnswer);
    my %options	= @_;
    
    my $answer_evaluator = new AnswerEvaluator;
    $answer_evaluator->{debug} = $options{debug};
    
    $correctAnswer =~ s/\\n/\n/g;

    $answer_evaluator->ans_hash( 	
	correct_ans       => $correctAnswer,
	type              => 'string_literal',
	score             => 0,
	);
    
    # remove all pre filters
    $answer_evaluator->install_pre_filter('reset');
    
    
    $answer_evaluator->install_evaluator(sub {
	my $rh_ans = shift;
	$rh_ans->{_filter_name} = "Evaluator: Compare string answers with eq";

	$rh_ans->{original_student_ans} =~ s/\r//g;
	$rh_ans->{correct_ans} =~ s/\r//g;
	chomp($rh_ans->{original_student_ans});
	chomp($rh_ans->{correct_ans});

	$rh_ans->{score} = ($rh_ans->{original_student_ans} eq $rh_ans->{correct_ans})?1:0  ;

#	WARN_MESSAGE(substr($rh_ans->{original_student_ans},19,1));
#	WARN_MESSAGE(substr($rh_ans->{correct_ans},19,1));

	return $rh_ans;
	
					 });
    
    # set up post filters to correctly format results in html
    $answer_evaluator->install_pre_filter('reset');    
    $answer_evaluator->install_post_filter(sub {
	my $rh_hash = shift; 
	$rh_hash->{_filter_name} = "clean up strings";
	my $string = $rh_hash->{student_ans};
	$string =~ s/\t/    /g;
	# tabs mess up the past answer database.  
	$rh_hash->{original_student_ans} =~ s/\t/    /g;
	$string = encode_pg_and_html($string);
	$string =~ s/&#10;/<br>/g;
	$string =~ s/ /&nbsp;/;

	$rh_hash->{'preview_text_string'} = $string;
	$rh_hash->{'preview_latex_string'} = $string;
	$rh_hash->{'student_ans'} = $string;

	$string = $rh_hash->{'correct_ans'};
	$string = encode_pg_and_html($string);
	$string =~ s/&#10;/<br>/g;
	$string =~ s/ /&nbsp;/;

	$rh_hash->{'correct_ans'} = $string;

	return $rh_hash;		
					   });
    
    
    return $answer_evaluator;
}

sub format_string {
    my $string = shift;
    
    $string =~ s/\\n/\n/g;

    if ($main::displayMode eq 'TeX' || 
	$main::displayMode eq 'Latex2HTML') {
	$string =~ s/\n/\newline/g;
    } elsif ($main::displayMode =~ /^HTML/){
	$string =~ s/\n/<br>/g;
	$string =~ s/&#10;/<br>/g;
	$string =~ s/ /&nbsp;/;
    }

    return $string;
}

sub random_word {
    return $word_list[random(0,$#word_list)];
}

sub random_sentence {
    return $sentence_list[random(0,$#sentence_list)];
}

sub random_phrase {
    return $phrase_list[random(0,$#phrase_list)];
}

@word_list= qw(abandoned apple bevelled butter ceres 
chicken despise depot eighth eject 
fatigue football gargoyle ghoulish hamper 
house infant ingest jack joint 
klaxon knead library lone meat
moon napalm north opal order
pause premonition queen quality roast
remand steel scene turnip trunk 
ulcer unnerve vent vanish water
world xavier young yawn zoom );

@python_keywords = qw( and       del       from      not       while
as        elif      global    or        with
assert    else      if        pass      yield
break     except    import    print
class     exec      in        raise
continue  finally   is        return 
def       for       lambda    try );

@java_keywords = qw( abstract 	continue 	for 	new 	switch
assert 	default 	goto 	package 	synchronized
boolean 	do 	if 	private 	this
break 	double 	implements 	protected 	throw
byte 	else 	import 	public 	throws
case 	enum 	instanceof 	return 	transient
catch 	extends 	int 	short 	try
char 	final 	interface 	static 	void
class 	finally 	long 	strictfp 	volatile
const 	float 	native 	super 	while  );

@sentence_list = (
    'The choral decays below the juice!',
    'Past the force fiddles the gateway.',
    'Its whim leans past the corrupt distress.',
    'The marketing of narrative authenticity interrogates the discourse of post-Jungian analysis.',
    'The discourse of the abyss may be seen as the ideology of exoticism.',
    'The soil sizes the crew.',
    'The piano punts!',
    'The museum triumphs!',
    'The social project confuses a boiled bankrupt.',
    'How will every climbing peanut lose?',
    'The east reaches a signal.',
    'The money emerges next to the wallet!',
    'When will the module invert a skilled comparison?',
    'How will butter apologize?',
    'A leaf fishes the razor.',
    'When can the calm safeguard an immoral energy?',
    'Why can the dog dance within the moon?',
    'The archive cautions opposite the cable.',
    'Her confident scholar errs in the heart.',
    'Over the dishonest fuel finishes your condemning attendant.');

@phrase_list = (
    'Eat your foot.',
    'I hate the green flashing light.', 
    'Hello. I have the urge to kill.', 
    'DO NOT DISTURB, evil genius at work.',
    'Rubber ducks are planning world domination!',
    'I know kung fu and 50 other dangerous words.',
    'Love your enemies, it makes them angry.', 
    'Do not mess with me! I have a stick!', 
    'Go away, evil Mr. Scissors!',
    'Ha ha! I do not get it.',
    'It is much funnier now that I get it.', 
    'Come to the dark side. We have cookies.', 
    'The decision is maybe and that’s final!', 
    'I am pretending to be a tomato.', 
    'Never put a cat on your head.', 
    'Do not eat my foot!', 
    'The banana has legs!', 
    'Do not worry, I was born this way.', 
    'We are so skilled!',
    );



1;
