import controlP5.*;

ControlP5 control5;

PImage img;
PImage rChannel;
PImage gChannel;
PImage bChannel;

PImage snow;
PImage tvFrame;

//filter parameters
int snowAlpha = 90;
int rollingBarAlpha = 110;
int rollingBarHeight = 70;
int rollingBarSpeedMultiplier = 9;
int hRgbShift = 4;
int vRgbShift = 6;
float scanlineDarkness = 0.4f;

//how many frames before the effect stabilizes
int powerOnFrames = 120;

//The settings the filter will stabilize to after the poweron effect
int powerOnSnowAlpha = 90;
int powerOnRollingBarSpeed = 16;
int powerOnHRgbShift = 4;
int powerOnVRgbShift = 6;

ChannelShiftMotion redX, redY, greenX, greenY, blueX, blueY;
ChannelShiftMotion[] shiftMotions = new ChannelShiftMotion[6];

int shiftSpeedDivisor = 20;

int flickerMinAlpha = 95;//percent

int rgbShiftMaxDuration = 45;//frames

public enum Channel {RED, GREEN, BLUE};
public enum Axis {X, Y};

class ChannelShiftMotion {
  
  float target;
  float offset;
  float speed;
  int flickerAlpha = 255;
  int shiftDurationRemaining = 0;
  Axis axis;
  
  public ChannelShiftMotion(float target, float offset, float speed, Axis axis) {
    this.target = target;
    this.offset = offset;
    this.speed = speed;
    this.axis = axis;
  }
  
}

void setup() {
  
  size(480, 270);
  
  tvFrame = loadImage("tv.png");
  tvFrame.resize(width, height);
  
  img = loadImage("obey.png");
  img.resize(width, height);
  
  rChannel = getChannel(img, Channel.RED); //<>//
  gChannel = getChannel(img, Channel.GREEN);
  bChannel = getChannel(img, Channel.BLUE);
  
  snow = createImage(width, height, RGB);
  
  buildControls();
  control5.hide();
  
  redX = new ChannelShiftMotion(0, 0, 0, Axis.X);
  redY = new ChannelShiftMotion(0, 0, 0, Axis.Y);
  greenX = new ChannelShiftMotion(0, 0, 0, Axis.X);
  greenY = new ChannelShiftMotion(0, 0, 0, Axis.Y);
  blueX = new ChannelShiftMotion(0, 0, 0, Axis.X);
  blueY = new ChannelShiftMotion(0, 0, 0, Axis.Y);
  
  shiftMotions[0] = redX;
  shiftMotions[1] = redY;
  shiftMotions[2] = greenX;
  shiftMotions[3] = greenY;
  shiftMotions[4] = blueX;
  shiftMotions[5] = blueY;
  
  noSmooth();
  
}

void draw() {
  background(0);
  
  //power on effect
  if(frameCount < powerOnFrames) {
    snowAlpha = int(map(frameCount, 0, powerOnFrames, 255, powerOnSnowAlpha));
    rollingBarSpeedMultiplier = int(map(frameCount, 0, powerOnFrames, 70, powerOnRollingBarSpeed));
    vRgbShift = int(map(frameCount, 0, powerOnFrames, 30, powerOnVRgbShift));
    hRgbShift = int(map(frameCount, 0, powerOnFrames, 20, powerOnHRgbShift));
  }
  
  //channel shifting
  for(int i = 0; i < shiftMotions.length; i++) {
    checkChannelMotion(shiftMotions[i]);
  }
  
  //draw red channel first
  tint(255, redX.flickerAlpha);
  image(rChannel, redX.offset, redY.offset);
  
  //swap to opposite multiplicative blending to draw green & blue channels
  blendMode(SCREEN);
  
  tint(255, redX.flickerAlpha);
  image(gChannel, greenX.offset, greenY.offset);
  
  tint(255, blueX.flickerAlpha);
  image(bChannel, blueX.offset, blueY.offset);
  
  //change blend mode back to default for scan lines, 
  //rolling bar, static snow, and the TV frame 
  blendMode(BLEND);
  tint(255, 255);
  drawScanLines();
  
  makeSnowFrame();
  tint(255, snowAlpha);
  image(snow, 0, 0);
  
  drawRollingBar(); 
  
  tint(255,255);
  image(tvFrame, 0,0);
  
  println(frameRate);
  
}

void drawScanLines() {
  loadPixels();
  
  for(int x = 0; x < width; x++) {
   
    for(int y = 0; y < height; y++) {
      
      if(y % 2 == 0) {
        int pixelLocation = (y * width) + x;
        float r = red(pixels[pixelLocation]);
        float g = green(pixels[pixelLocation]);
        float b = blue(pixels[pixelLocation]);
        
        r *= scanlineDarkness;
        g *= scanlineDarkness;
        b *= scanlineDarkness;
        
        r = constrain(r, 0, 255);
        g = constrain(g, 0, 255);
        b = constrain(b, 0, 255);
        
        color c = color(r, g, b);
        pixels[pixelLocation] = c;
      }
    
    }
  }
  updatePixels();
}

void makeSnowFrame() {
  snow.loadPixels();
  for(int i = 0; i < snow.pixels.length; i++) {
    snow.pixels[i] = color(random(255));
  }
  snow.updatePixels();
}

void drawRollingBar() {
  noStroke();
  fill(0, rollingBarAlpha);
  int yLoc = frameCount * rollingBarSpeedMultiplier;
  int areaHeight = height + rollingBarHeight*3;
  rect(0, (yLoc % areaHeight) - rollingBarHeight*3, width, rollingBarHeight);
}

/*
* Strips a single color channel out of a PImage.
* This could be accomplished with less code using bit masking,
* but this approach is more readable
*/
PImage getChannel(PImage source, Channel c) {
  PImage result = source.get();
  result.loadPixels();
  for(int i = 0; i < source.width * source.height; i++) {
    switch(c){
      case RED:
      result.pixels[i] = color(red(source.pixels[i]), 0, 0);
      break;
      case GREEN:
      result.pixels[i] = color(0, green(source.pixels[i]), 0);
      break;
      case BLUE:
      result.pixels[i] = color(0, 0, blue(source.pixels[i]));
      break;
    }
  }
  result.updatePixels();
  
  return result;
}

void checkChannelMotion(ChannelShiftMotion channel) {
  if(channel.shiftDurationRemaining <= 0 || (channel.target <= 0 && channel.offset <= channel.target) || (channel.target >= 0 && channel.offset >= channel.target)) {
   //set up a new animation
   if(channel.axis == Axis.Y) {
     channel.target = int(random(-1*vRgbShift, vRgbShift));
   } else {
     channel.target = int(random(-1*vRgbShift, vRgbShift));
   }
   channel.shiftDurationRemaining = int(random(rgbShiftMaxDuration));
   channel.speed = int(random(1, shiftSpeedDivisor));
   
   //change the alpha to make the channel flicker a bit
   int flicker = (int)random(flickerMinAlpha, 100);
   channel.flickerAlpha = int(map(flicker, 0, 100, 0, 255));
   
  } else {
    float shift = abs((channel.offset - channel.target) / shiftSpeedDivisor);
    if(channel.target <= 0 && channel.offset > channel.target) {
      channel.offset -= shift;
    } else if(channel.target >= 0 && channel.offset < channel.target) {
      channel.offset += shift;
    }
  }
  channel.shiftDurationRemaining--;
}

void buildControls() {
  
  control5 = new ControlP5(this);
  
  control5.addSlider("rollingBarSpeedMultiplier")
  .setPosition(50, 20)
  .setRange(0, 50)
  .setSize(100, 20);
  
  control5.addSlider("snowAlpha")
  .setPosition(50, 50)
  .setRange(0, 255)
  .setSize(100, 20);
  
  control5.addSlider("vRgbShift")
  .setPosition(50, 80)
  .setRange(0, 35)
  .setSize(100, 20);
  
  control5.addSlider("hRgbShift")
  .setPosition(50, 110)
  .setRange(0, 35)
  .setSize(100, 20);
  
  control5.addSlider("rollingBarAlpha")
  .setPosition(50, 140)
  .setRange(0, 255)
  .setSize(100, 20);
  
  control5.addSlider("rollingBarHeight")
  .setPosition(50, 170)
  .setRange(0, 150)
  .setSize(100, 20);
  
}

void keyPressed() {
  if(!control5.isVisible()) {
    control5.show();
  } else {
    control5.hide();
  }
}