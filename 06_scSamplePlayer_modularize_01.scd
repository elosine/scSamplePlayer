

////
s.sendMsg(\s_new, \phasorclock, 3001, 0, 2001, \abus, 101, \kbus, 1, \bpc, 16, \stbpm, 50, \endbpm, 50, \rampdur, 0.01, \t_tr, 1);
(
s.options.memSize = 1000000;
s.waitForBoot{ fork{
	var sampspath, samps, bufs1024, proc, gr, indexbus;
	proc = NetAddr("127.0.0.1", 12321);
	sampspath = thisProcess.nowExecutingPath.dirname ++ "/samples/*";
	samps = SoundFile.collectIntoBuffers( sampspath );
	bufs1024 = Array.newClear(0);
	samps.do{ | it |
		it.loadToFloatArray( action:{ |array|
			bufs1024 = bufs1024.add( array.resamp1(1024) );
	})};
	OSCdef(\getwaveform, {
		arg msg;
		var temparray, sampnum;
		sampnum = msg[1].asInteger;
		temparray = bufs1024[sampnum].copy;
		temparray = temparray.insert(0, sampnum);
		temparray = temparray.insert(0, "/sbuf".asString);
		proc.sendBundle(0.0, temparray);
	}, "/getwaveform");
SynthDef(\bufrd, {
	arg buf, spd=1, start=0.0, end=1.0, kbus, och=0,  atk=0.015, sus=1, decay=0, rel=0.05, crv=2.neg, t_trigstart=0, envdoneact=0;
	var index, indexnorm;
	var sig, env, trig, relsamps, dir;
	index = Phasor.ar( t_trigstart, BufRateScale.kr(buf)*spd, start*BufFrames.kr(buf), end*BufFrames.kr(buf) );
	indexnorm = index.linlin(0.0, BufFrames.kr(buf), 0.0, 1.0);
	Out.kr(kbus, indexnorm);
	relsamps = SampleRate.ir()*rel;
	dir = spd < 0;
	trig = Select.ar( dir, [
		( index <= ( (BufFrames.kr(buf)*end) - relsamps )  ),
		( index >= ( (BufFrames.kr(buf)*start) + relsamps )  )
	] );
	env = EnvGen.ar( Env.adsr(atk, decay, sus, rel, curve:crv), trig, doneAction:envdoneact);
	sig = BufRd.ar(2, buf, index);
	Out.ar(och, sig*env);
}).add;
	indexbus = Bus.control(s);
	OSCdef(\getix, {
		arg msg;
		var sampnum = msg[1].asInteger;
		indexbus.get( { arg val; proc.sendMsg("/ix", sampnum, val.asFloat) } )
	}, "/getix");
	OSCdef(\startendpts, { |msg|
		var start = msg[1].asFloat;
		var end = msg[2].asFloat;
		b.set(\start, start, \end, end);
	}, "/startendpts");
} }//end fork; end s.waitForBoot
)
