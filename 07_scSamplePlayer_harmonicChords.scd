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
		arg buf, spd=1, start=0.0, end=1.0, kbus, och=0,  atk=0.015, sus=1, decay=0, rel=0.015, crv=2.neg, envdoneact=0, amp=0.7;
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
		Out.ar(och, sig*env*amp);
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
		~startendpts = [ start, end];
		~s0.set( \start, start, \end, end);
	}, "/startendpts");
	OSCdef( \chgsamp, {|msg|
		var sampnum = msg[1].asInteger;
		var temparray;
		temparray = ~bufs1024[sampnum].copy;
		temparray = temparray.insert(0, sampnum);
		temparray = temparray.insert(0, "/sbuf".asString);
		//Change synth sample
		~s0.set(\buf, ~samps[sampnum].bufnum);
		//Send new waveform to Processing
		~proc.sendBundle(0.0, temparray);
	}, "/chgsamp");
	n = NetAddr("localhost", NetAddr.langPort);
	~gr = [Group.new(s)];
	12.do{|ix| ~gr = ~gr.add(Group.after(~gr[ix]))};
	SynthDef(\audioroute, {
		|ich och=0 atk=0.015 decay=0 sus=1 rel=0.015 crv amp=0.8 gate=1|
		Out.ar( och, In.ar(ich,2)*EnvGen.ar(Env.adsr(atk,decay,sus, rel,curve:crv),gate)*amp);
	}).add;
	0.2.wait;
	//Make Synth
	~s0 = Synth(\bufrd, [\buf, ~samps[0], \kbus, 	~indexbus], ~gr[3]);
} }//end fork; end s.waitForBoot
)

// buf, spd, start, end, kbus, och,  atk, sus, decay, rel, crv, envdoneact, t_trigstart;

//Find Sample
n.sendMsg("/chgsamp", 17);
~startendpts
~basespd = 0.5.neg;
~st = 0.1474609375;
~nd = 0.2255859375;
~ar1 = Synth(\audioroute, [\ich, 30], ~gr[5]);
//base
~s0.set(\spd, ~basespd, \atk, 0.1, \rel, 0.05, \start, ~st, \end, ~nd, \amp, 0.1, \och, 30);
//fifth 3:2
~s2 = Synth(\bufrd, [\buf, ~samps[17], \spd, ((~basespd*3)/2), \start, ~st, \end, ~nd, \atk, 0.1, \rel, 0.1, \amp, 0.1, \och, 30], ~gr[3]);
//m3 6:5
~s3 = Synth(\bufrd, [\buf, ~samps[17], \spd, ((~basespd*6)/5), \start, ~st, \end, ~nd, \atk, 0.1, \rel, 0.1, \amp, 0.1, \och, 30], ~gr[3]);
//Pythagorean minor seventh 16:9
~s4 = Synth(\bufrd, [\buf, ~samps[2], \spd, ((~basespd*16)/9), \start, v, \end, ~nd, \atk, 0.1, \rel, 0.1, \amp, 0.1, \och, 30], ~gr[3]);
//5-limit wolf fourth + octave 27:20*2
~s5 = Synth(\bufrd, [\buf, ~samps[2], \spd, ( (~basespd*27*2)/20 ), \start, ~st, \end, ~nd, \atk, 0.1, \rel, 0.1, \amp, 0.1, \och, 30], ~gr[3]);
~s5.set(\amp, (0.1.ampdb -6).dbamp );
//Golden ratio approximation 233:144
~s6 = Synth(\bufrd, [\buf, ~samps[2], \spd, ( (~basespd*233)/144 ), \start, ~st, \end, ~nd, \atk, 0.1, \rel, 0.1, \amp, 0.1, \och, 30], ~gr[3]);
//Just major sixth 5:3 down octave
~s7 = Synth(\bufrd, [\buf, ~samps[2], \spd, ( (~basespd*5*0.5)/3 ), \start, ~st, \end, ~nd, \atk, 0.1, \rel, 0.1, \amp, 0.1, \och, 30], ~gr[3]);
~s7.set(\amp, (0.1.ampdb + 4).dbamp );


//way to bring samples in and out


Server.default.record;
Server.default.stopRecording;





