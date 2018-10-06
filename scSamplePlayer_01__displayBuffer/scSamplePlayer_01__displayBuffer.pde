import oscP5.*;
import netP5.*;

OscP5 osc;
NetAddress sc;

int bufsize = 1024;
int margin = 10;
int trackheight = 200;
float[] samparray;
int sampnum = 3;
int trackmidY = 110;

void setup() {
  size( 1044, 500 );
  OscProperties prop = new OscProperties();
  prop.setListeningPort(12321);
  prop.setDatagramSize(15360);
  osc = new OscP5(this, prop);
  sc = new NetAddress("127.0.0.1", 57120);
  //initialize samparray with 0 values
  samparray = new float[bufsize];
  for (int i=0; i<bufsize; i++) samparray[i] = 0;
}

void draw() {
  background(0);
  ////draw waveform
  strokeWeight(1);
  stroke(255);
  //To display the waveform, 
  //we will draw a line from every point in the resampled buffer array
  //to the next point in the array
  //the signal is a bipolar one, it goes from 1 to -1
  //the line object (x1, y1, x2, y2)
  //will draw from ( x1: current array index + left margin, y1: current array value * trackheight/2
  // x2: next array index + left margin, y1: next array value * trackheight/2)
  //(need to start on index 1 so we don't go out of bounds on the last point)
  //also need to multiply y values by 1 because 0 is at the top and sketch height
  //is at the bottom in this case 500px
  for (int i=1; i<bufsize; i++) {
    line( i-1 + margin, ( ( samparray[i-1]*(trackheight/2) ) * -1 ) + trackmidY, 
      i + margin, ( ( samparray[i]*(trackheight/2) ) * -1 ) + trackmidY );
  }
}

//oscEvent, when a message with the tag "/sbuf" is received
// will receive the array from supercollider
//and populate the samparray array with the values
void oscEvent(OscMessage msg) {
  if ( msg.checkAddrPattern("/sbuf") ) { 
    sampnum = msg.get(0).intValue(); //stores sample number, will use this later
    //start on index 1 because msg[0] is the metadata sampnum
    for (int i=1; i<bufsize; i++) {
      samparray[i] = msg.get(i).floatValue();
    }
  }
}

void mousePressed(){
 OscMessage getwf = new OscMessage("/getwaveform");
  getwf.add(0);
  osc.send(getwf, sc);
}