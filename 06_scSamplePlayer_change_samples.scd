(
s.options.memSize = 1000000;
s.waitForBoot{ fork{
	~proc = NetAddr("127.0.0.1", 12321);
	~samps = SoundFile.collectIntoBuffers( thisProcess.nowExecutingPath.dirname ++ "/samples/*" );
	~bufs1024 = Array.newClear(0);
	~samps.do{ | it |
		it.loadToFloatArray( action:{ |array|
			~bufs1024 = ~bufs1024.add( array.resamp1(1024) );
	})};
	SynthDef(\bufrd, {
		arg buf, spd=1, start=0.0, end=1.0, kbus, och=0,  atk=0.015, sus=1, decay=0, rel=0.015, crv=2.neg, envdoneact=0;
		var index, indexnorm;
		var sig, env, trig, relsamps, dir;
		index = Phasor.ar( \t_trigstart.kr(0, 0), BufRateScale.kr(buf)*spd, start*BufFrames.kr(buf), end*BufFrames.kr(buf), start*BufFrames.kr(buf));
		indexnorm = index.linlin(0.0, BufFrames.kr(buf), 0.0, 1.0);
		Out.kr(kbus, indexnorm);
		relsamps = abs(SampleRate.ir()*rel*spd);
		dir = spd < 0;
		trig = Select.ar( dir, [
			( index <= ( (BufFrames.kr(buf)*end) - relsamps )  ),
			( index >= ( (BufFrames.kr(buf)*start) + relsamps )  )
		] );
		env = EnvGen.ar( Env.adsr(atk, decay, sus, rel, curve:crv), trig, doneAction:envdoneact);
		sig = BufRd.ar(2, buf, index);
		Out.ar(och, sig*env);
	}).add;
	~indexbus = Bus.control(s);
	OSCdef(\getix, {
		arg msg;
		var sampnum = msg[1].asInteger;
		~indexbus.get( { arg val; ~proc.sendMsg("/ix", sampnum, val.asFloat) } )
	}, "/getix");
	OSCdef(\startendpts, { |msg|
		var start = msg[1].asFloat;
		var end = msg[2].asFloat;
		msg.postln;
		~s1.set( \start, start, \end, end);
	}, "/startendpts");
	0.2.wait;
	//Make Synth
	~s1 = Synth(\bufrd, [\buf, ~samps[0], \kbus, 	~indexbus]);
	//Make OSCdef to:
	//// 2) Create sample synth
	//// 3) Send Array to Processing
	OSCdef( \chgsamp, {|msg|
		var sampnum = msg[1].asInteger;
		var temparray;
		temparray = ~bufs1024[sampnum].copy;
		temparray = temparray.insert(0, sampnum);
		temparray = temparray.insert(0, "/sbuf".asString);
		//Change synth sample
		~s1.set(\buf, ~samps[sampnum].bufnum);
		//Send new waveform to Processing
		~proc.sendBundle(0.0, temparray);
	}, "/chgsamp");
} }//end fork; end s.waitForBoot
)

n = NetAddr("localhost", NetAddr.langPort);
n.sendMsg("/chgsamp", 4);
~s1.set(\spd, -0.1);
~s1.set(\t_trigstart, 1, \rel, 0.01, \atk, 1.2, \crv, 4);

~s1.set(\spd, 0.1, \rel, 0.015, \t_trigstart, 1, \envdoneact, 1).run;
~s1.set(\envdoneact, 0).run;
~s1.set(\t_trigstart, 1)
