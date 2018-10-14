//See bufrd synthdef
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
	//add t_trigstart to phasor.ar's first argument trig
//this triggers phasor back to 0
//the 't_' nomenclature gives a trigger rate argument
//IOW, normally you would have to send a trig 0 then a trig 1 to trigger it back to the beginning
//as the trig arg in Phasor.ar requires a change
//A t_ trigger rate argument will automatically trigger the action without reseting to 0 first
	//Also added the arg envdoneaction. This will allow external control over the envelope's doneAction arg
	//doneAction:0 does nothing, doneAction:1 pauses the synth, and doneAction:2 kills the synth when the envelope has finished
SynthDef(\bufrd, {
	arg buf, spd=1, start=0.0, end=1.0, kbus, och=0,  atk=0.015, sus=1, decay=0, rel=0.05, crv=2.neg, t_trigstart=0, envdoneact=0;
	var index, indexnorm;
	var sig, env, trig, relsamps, dir;
	index = Phasor.ar( t_trigstart, BufRateScale.kr(buf)*spd, start*BufFrames.kr(buf), end*BufFrames.kr(buf) );
	indexnorm = index.linlin(0.0, BufFrames.kr(buf), 0.0, 1.0);
	Out.kr(kbus, indexnorm);
	relsamps = SampleRate.ir()*rel; //release time in #ofsamples
	dir = spd < 0; //gives 1 if negative, 0 if positive
	//select makes the trigger rel#ofsamples before the end time if going forward or rel#ofsamples before the start time if going backwards; the boolean operators (<= >=) yield 1 if true or 0 if false perfect for the envelope gate/trigger; 0 releases the envelope and 1 attacks. So when moving forward when the index gets to the release time, the trigger turns 0 because it is > the trigger time and when the index resets to start the sample again it turns to 1 because it is <= to the trigger time
	trig = Select.ar( dir, [
		( index <= ( (BufFrames.kr(buf)*end) - relsamps )  ),
		( index >= ( (BufFrames.kr(buf)*start) + relsamps )  )
	] );
	env = EnvGen.ar( Env.adsr(atk, decay, sus, rel, curve:crv), trig, doneAction:envdoneact); //trigger the envelope
	sig = BufRd.ar(2, buf, index);
	Out.ar(och, sig*env);
}).add;
	//Had to combine two synthdefs
	//To make an internal envelope for every time the sample/part sample repeats
	// 1) calculate the release time in number of samples
	// 2) figure out which direction you are going
	// 3) create a trigger that will trigger either rel#of-samples before the end time or rel#of-samples before the start time, depending on which direction you are going
	// 4) trigger the release of the envelope, then trigger the attack when the sample restarts
	0.1.wait; //little pause here so that the synthdefs are registered before trying to instantiate them
	indexbus = Bus.control(s);
	a = Synth(\bufrd, [\buf, samps[4],]);
	//Send the normalized Phasor signal to Processing so it can scroll through the waveform
	//Use OSCdef so that Processing requests the data and then SC sends it
	//We are going to use the Bus object on the sclang side to create some control bus proxies
	//so we can point to them easily. See above the synths.
	OSCdef(\getix, {
		arg msg;
		var sampnum = msg[1].asInteger;
		indexbus.get( { arg val; proc.sendMsg("/ix", sampnum, val.asFloat) } )
	}, "/getix");
	//OSCdef to get start/stop points from processing and set synths
	OSCdef(\startendpts, { |msg|
		var start = msg[1].asFloat;
		var end = msg[2].asFloat;
		b.set(\start, start, \end, end);
	}, "/startendpts");
} }//end fork; end s.waitForBoot
)
//send a set msg that restarts the sample and then pauses the synth after the envelope is done
a.set(\spd, 0.3, \t_trigstart, 1, \envdoneact, 1)
//to restart the synth us synth.run
//here we change \envdoneact to 0 so that the synth loops again and then run it
a.set(\envdoneact, 0).run
//to retrigger add .run
a.set(\spd, 0.3, \t_trigstart, 1, \envdoneact, 1).run
