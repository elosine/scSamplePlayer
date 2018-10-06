(
s.options.memSize = 1000000;
s.waitForBoot{ fork{
	var sampspath, samps, bufs1024, proc, gr, indexbus;
	proc = NetAddr("127.0.0.1", 12321);
	sampspath = thisProcess.nowExecutingPath.dirname ++ "/samples/*"; //thisProcess.nowExecutingPath.dirname gives you the current directory your patch is in; and then pointing to a folder called "samples" in the same directory
	samps = SoundFile.collectIntoBuffers( sampspath ); //this loads all the soundfiles in the folder directed to by sampspath variable to an array of buffers "samps"
	//Resample all buffers to 1024 float arrays for display
	// You have read the buffers from the server, and convert them to float arrays on the language side to be manipulated by sclang, then resample them to 1024 length with linear interpolation
	bufs1024 = Array.newClear(0); //empty array to store resampled buffers for display
	samps.do{ | it | //sclang style for loop; it is the actual buffer being passed in from samps as an argument the || notation is a shorthand for args; you can list them this way without the word 'arg' and with spaces between the args with no commas
		it.loadToFloatArray( action:{ |array| //look up the .loadToFloatArray function in the Buffer help file
			bufs1024 = bufs1024.add( array.resamp1(1024) ); //add the resampled array to bufs 1024
	})};
	//This OSCdef allows the Processing app to request a particular waveform which will be sent back to Processing
	OSCdef(\getwaveform, {
		arg msg;
		var temparray, sampnum;
		sampnum = msg[1].asInteger; //this is the sample/buffer number you are interested in as sent from Processing
		temparray = bufs1024[sampnum].copy; //create a temporary copy of the bufs1024 display array so you don't change the original
		//Processing will just read through the entire array so any meta data needs to be stuck into the array
		temparray = temparray.insert(0, sampnum); //insert the sample number at the beginning of the array so processing can keep track of which sample is being displayed
		temparray = temparray.insert(0, "/sbuf".asString); //insert the OSC tag at the front
		proc.sendBundle(0.0, temparray);
	}, "/getwaveform");
	//A phasor based SynthDef for to index through the buffer
	//We will be reading out the phasor signal to an audio bus (see Bus)
	//Also a normalized version of the signal wil be read out to a control bus
	//which will eventually be sent to the processing patch for cursor control
	SynthDef(\bufix, {
		arg buf, spd=1, start=0.0, end=1.0, abus, kbus;
		var indexer, indexernorm;
		//Phasor.ar's 2nd arg is looking for a rate
		//This is the speed per sample
		//BufRateScale basically compares the sc sample rate
		//with the sample rate of the sample
		//BufFrames.kr is the total number of samples in the buffer
		indexer = Phasor.ar(0, BufRateScale.kr(buf)*spd,
			start*BufFrames.kr(buf), end*BufFrames.kr(buf));
		indexernorm = indexer.linlin(0.0, BufFrames.kr(buf), 0.0, 1.0);
		Out.ar(abus, indexer);
		Out.kr(kbus, indexernorm);
	}).add;
	//SynthDef to read the buffer
	SynthDef(\bufrd,{
		arg och=0, buf, idxbus, gate=1, atk=0.015, sus=1, decay=0, rel=0.1, crv=2.neg;
		var sig, idx, env;
		env = EnvGen.ar( Env.adsr(atk, decay, sus, rel, curve:crv), gate, doneAction:2);
		idx = In.ar(idxbus);
		sig = BufRd.ar(2, buf, idx);
		Out.ar(och, sig*env);
	}).add;
	//To read through the buffer we start a phasor index
	//then pass the index through an audio bus to a \bufrd synth
	//SuperCollider, since it is a REPL language, has a group system
	//for scheduling order of tasks see Group
	//We create the groups and add the \bufix synth to a group befor the \bufrd group
	//Creates an array of 11 groups one following the other
	gr = [Group.new(s)];
	10.do{ |ix| gr = gr.add( Group.after(gr[ix]) ) };
	//we'll use simple variables for the synths for now but later
	//we'll need something more elaborate to keep track of the different synths
	//Synth args: synthdef name, argument name/argument value pairs in an array, target group
	//Also notice the index is going to audio bus #30 and the \bufpl synth is reading its index
	//from audio bus #30
	0.1.wait; //little pause here so that the synthdefs are registered before trying to instantiate them
	indexbus = Bus.control(s);
	a = Synth(\bufix, [\buf, samps[0], \abus, 30, \kbus, indexbus], gr[0]); //sending normalized sig to the controlbus 'indexbus'
	b = Synth(\bufrd, [\buf, samps[0], \idxbus, 30], gr[1]);
	//Send the normalized Phasor signal to Processing so it can scroll through the waveform
	//Use OSCdef so that Processing requests the data and then SC sends it
	//We are going to use the Bus object on the sclang side to create some control bus proxies
	//so we can point to them easily. See above the synths.
	OSCdef(\getix, {
		arg msg;
		var sampnum = msg[1].asInteger;
		msg.postln;
		indexbus.get( { arg val; proc.sendMsg("/ix", sampnum, val.asFloat) } )
	}, "/getix");
} }//end fork; end s.waitForBoot
)






