/*
Theory:
 Most of the work will be done in Processing
 1) It will be helpful to define the 'track' region more precisely
 2) Detect if mouse is in track area
 3) Click will store start point
 4) Mouse release will store end point
 5) Do some math so you can drag either direction
 6) Highlight the selected area
 7) Right-click to remove selection
 */import oscP5.*;
import netP5.*;

OscP5 osc;
NetAddress sc;

int bufsize = 1024;
float[] samparray;
int sampnum = 3;
float csrx = 0;
int margin = 15;
//Define track bounding box and center
int tl, tt, tr, tb, trackwidth;
int trackheight = 300;
float trackhalfheight;
float trackcenter;
//variables to store selection points & highlighting
float range1 = 0;
float range2 = 0;
boolean highlight = false;

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
  //make an osc plug to recieve index see OSCP5:OSCplug
  osc.plug(this, "ix", "/ix");
  //Define track bounding box and center
  tl = margin;
  tt = margin;
  trackwidth = bufsize;
  tr = tl + trackwidth;
  tb = tt + trackheight;
  trackhalfheight = trackheight/2;
  trackcenter = tt + (trackheight/2);
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
    line( i-1 + tl, ( ( samparray[i-1] * trackhalfheight ) * -1 ) + trackcenter, 
      i + tl, ( ( samparray[i] * trackhalfheight ) * -1 ) + trackcenter );
  }
  //HIGHLIGHT
  if (highlight) {
    noStroke();
    fill(255, 255, 0, 150);
    rect(range1, tt, range2-range1, trackheight);
  }

  //CURSOR
  //Get CursorX
  osc.send("/getix", new Object[]{0}, sc);
  //Draw Cursor
  strokeWeight(3);
  stroke(153, 255, 0);
  line(csrx, tt, csrx, tb);
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

void mousePressed() {
  //for partial sample selection
  //is the mouse on the track
  if ( mouseX>=tl && mouseX<=tr && mouseY>=tt && mouseY<=tb) {
    //turn on highlighting
    highlight = true;
    range1 = mouseX;
  }
  //right click to remove selection
  if (mouseButton == RIGHT) {
    highlight = false;
    range1 = tl;
    range2 = tr;
  }
  OscMessage getwf = new OscMessage("/getwaveform");
  getwf.add(0);
  osc.send(getwf, sc);
}

void mouseDragged() {
  range2 = mouseX; //to extend highlight as you drag mouse
}

void mouseReleased() {
  //is the mouse on the track
  if ( mouseX>=tl && mouseX<=tr && mouseY>=tt && mouseY<=tb) {
    if (mouseButton != RIGHT) {
      range2 = mouseX;
      //figure out which is the actual start point
      if (range2<range1) {
        float range1temp = range1;
        range1 = range2;
        range2 = range1temp;
      }
      //normalize and send to sc
      float range1norm = norm(range1, tl, tr);
      float range2norm = norm(range2, tl, tr);
      osc.send("/startendpts", new Object[]{range1norm, range2norm}, sc);
      println(range1norm +":"+ range2norm);
    } else {
      osc.send("/startendpts", new Object[]{0, 1}, sc);
    }
  }
}



//function for OSCplug see OSCP5:OSCplug
void ix(int num, float val) {
  csrx = map(val, 0.0, 1.0, tl, tr);
}