(
s.options.memSize = 1000000;
s.waitForBoot{ fork{
	var sampspath, samps, bufs1024, proc;
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
} }//end fork; end s.waitForBoot
)



