/*
 * Processing_fadecandy_halloween.pde
 *
 The fire effect has been used quite often for oldskool demos.
 First you create a palette of N colors ranging from red to
 yellow (including black). For every frame, calculate each row
 of pixels based on the two rows below it: The value of each pixel,
 becomes the sum of the 3 pixels below it (one directly below, one
 to the left, and one to the right), and one pixel directly two
 rows below it. Then divide the sum so that the fire dies out
 as it rises.
 */

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.Arrays;

// size of fire effect
final int nColors = 1024;
final int tileHeight = 4096;

int[] fire_buffer;  // effect goes here
int[] flame_palette; // flame colors
int[] tile;    // perlin noise lookup table

int widthLeft;
int widthRight;
int fire_length;

String filename = "pumpkin-1293079_1280.png";
PImage halloweenImg;
PImage flamesImg;

final int flamesWidth = 256;
final int flamesHeight = 256;

OPC opc;
final String fcServerHost = "127.0.0.1";
final int fcServerPort = 7890;

final int boxesAcross = 2;
final int boxesDown = 2;
final int ledsAcross = 8;
final int ledsDown = 8;
// initialized in setup()
float spacing;
int x0;
int y0;

int exitTimer = 0; // Run forever unless set by command line

void setup() {

  apply_cmdline_args();

  size(640, 480);

  frameRate(120);

  flamesImg = createImage(flamesWidth, flamesHeight, RGB); // TODO maybe try with some alpha

  flame_palette = makeFlamePalette();

  widthLeft = flamesWidth - 1;
  widthRight = flamesWidth + 1;

  fire_length = flamesWidth * flamesHeight;
  fire_buffer = new int[fire_length + widthRight];

  // tile = makeTileSimple(flamesWidth, tileHeight);
  tile = makeTileComplex(flamesWidth, tileHeight);
  tileStats(tile);

  // saveInts("_perlin_fire_4096_1024.dat", tile);

  noSmooth();
  Arrays.fill(fire_buffer, 0, fire_length, nColors / 8);

  background(0);

  // Connect to an instance of fcserver
  opc = new OPC(this, fcServerHost, fcServerPort);
  opc.showLocations(false);

  spacing = (float)min(height / (boxesDown * ledsDown + 1), width / (boxesAcross * ledsAcross + 1));
  x0 = (int)(width - spacing * (boxesAcross * ledsAcross - 1)) / 2;
  y0 = (int)(height - spacing * (boxesDown * ledsDown - 1)) / 2;

  final int boxCentre = (int)((ledsAcross - 1) / 2.0 * spacing); // probably using the centre in the ledGrid8x8 method
  int ledCount = 0;
  for (int y = 0; y < boxesDown; y++) {
    for (int x = 0; x < boxesAcross; x++) {
      opc.ledGrid8x8(ledCount, x0 + spacing * x * ledsAcross + boxCentre, y0 + spacing * y * ledsDown + boxCentre, spacing, 0, false, false);
      ledCount += ledsAcross * ledsDown;
    }
  }

  halloweenImg = scaleCentreForDisplay(loadImage(filename));
}

void draw() {

  // look up table - should be fastest
  arrayCopy(tile, (frameCount % tileHeight) * flamesWidth, fire_buffer, fire_length, flamesWidth);

  flamesImg.loadPixels();

  // Do the fire calculations for every pixel, from top to bottom
  int currentPixel = 0;

  for (int currentPixelIndex = 0; currentPixelIndex < fire_length; currentPixelIndex++) {
    // Add pixel values around current pixel
    // Output everything to screen using our palette colors
    fire_buffer[currentPixelIndex] = currentPixel=
      ((fire_buffer[currentPixelIndex]
      + fire_buffer[currentPixelIndex + widthLeft]
      + fire_buffer[currentPixelIndex + flamesWidth]
      + fire_buffer[currentPixelIndex + widthRight])>>2)-1;

    if (currentPixel > 0)
      flamesImg.pixels[currentPixelIndex] = flame_palette[currentPixel];
  }

  // for (int y = 0; y < flamesHeight; y++) {
  //   currentPixel = y * (nColors - flamesWidth) / flamesHeight;
  //   for (int x = 0; x < flamesWidth; x++) {
  //     flamesImg.pixels[x + y * flamesWidth] = flame_palette[currentPixel++];
  //   }
  // }

  flamesImg.updatePixels();

  // ADD 8 of 10
  // SUBTRACT 9 of 10 (goulish)
  // DARKEST  10 of 10
  // LIGHTEST 5 of 10 (heap of fire)
  // MULTIPLY 7 of 10
  // OVERLAY 8 of 10
  // SOFT_LIGHT 9 of 10
  // DODGE 10 of 10

  PImage tmp = createImage(halloweenImg.width, halloweenImg.height, RGB);
  tmp.copy(halloweenImg, 0, 0, halloweenImg.width, halloweenImg.height, 0, 0, tmp.width, tmp.height);
  tmp.blend(flamesImg, 0, 0, flamesImg.width, flamesImg.height, 0, 0, tmp.width, tmp.height, SOFT_LIGHT);
  image(tmp, 0, 0);

  // image(flamesImg, 0, 0);

  fill(128);
  text(String.format("%5.1f fps", frameRate), 5, 15);

  check_exit();
}

int scale(int i, int end, int max) {
  return i * max / end;
}

PImage scaleCentreForDisplay(PImage src) {
  PImage dest = createImage(width, height, RGB);
  int widthScale = 0;
  int heightScale = 0;
  if (src.height / src.width > height / width) {
    heightScale = height;
  } else {
    widthScale = width;
  }
  src.resize(widthScale, heightScale);
  dest.copy(src, 0, 0, src.width, src.height, (width - src.width) / 2, (height - src.height) / 2, src.width, src.height);

  return dest;
}

int[] makeFlamePalette() {
  int flame_palette[] = new int[nColors];

  // generate flame color palette in RGB. need 256 bytes available memory

  // for (int i=0; i<nColors/4; i++)
  // {
  //   flame_palette[i]  = color(scale(i,nColors/4,64<<2), 0, 0 /*,scale(i,nColors/4,64<<3) */);      // Black to red
  //   flame_palette[i+nColors/4]  = color(255, scale(i,nColors/4,64<<2), 0); // Red to yellow
  //   flame_palette[i+nColors/2]  = color(255, 255, scale(i,nColors/4,64<<2)); // Yellow to white,
  //   flame_palette[i+3*nColors/4]  = color(255, 255, 255);   // White
  // }

  int rMin = 0;
  int rMax = 240;
  int gMin = 50;
  int gMax = 480;
  int bMin = 100;
  int bMax = 960;
  for (int i = 0; i < nColors; i++) {
    int r = (i >= rMin && i <= rMax) ? 255 * (i - rMin) / rMax : ( i < rMin) ? 0 : 255;
    int g = (i >= gMin && i <= gMax) ? 255 * (i - gMin) / gMax : ( i < gMin) ? 0 : 255;
    int b = (i >= bMin && i <= bMax) ? 255 * (i - bMin) / bMax : ( i < bMin) ? 0 : 255;
    flame_palette[i]  = color(r, g, b);
  }

  return flame_palette;
}


float ns = 0.015;  //increase this to get higher density
float tt = 0;

int[] makeTileSimple(int w, int h) {

  double minNoise = 0;
  double maxNoise = 0;
  double[] noiseSimple = new double[w*h];

  int[] tile = new int[w*h];
  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      double noises = noise((float)(x*ns), (float)((x*h+y)*ns), 0);
      if (x == 0 && y == 0) {
        minNoise = maxNoise = noises;
      } else {
        minNoise = Math.min(minNoise, noises);
        maxNoise = Math.max(maxNoise, noises);
      }
      noiseSimple[x + y*w] = noises;
    }
  }

  println(String.format("noiseSimple min%6.3f max%6.3f", minNoise, maxNoise));

  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      int value = (int)((nColors - 1) * ((noiseSimple[x + y*w] - minNoise) / (maxNoise - minNoise)));
      tile[x + y*w] = value;
    }
  }

  return tile;
}

int[] makeTileComplex(int w, int h) {

  int[] tile = new int[w*h];
  double[] noiseComplex = new double[w*h];

  double minNoise = 0;
  double maxNoise = 0;

  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      float u = (float) x / w;
      float v = (float) y / h;
      double noise00 = noise((x*ns), (y*ns),0);
      double noise01 = noise(x*ns, (y+h)*ns,tt);
      double noise10 = noise((x+w)*ns, y*ns,tt);
      double noise11 = noise((x+w)*ns, (y+h)*ns,tt);
      double noisec = u*v*noise00 + u*(1-v)*noise01 + (1-u)*v*noise10 + (1-u)*(1-v)*noise11;
      if (x == 0 && y == 0) {
        minNoise = maxNoise = noisec;
      } else {
        minNoise = Math.min(minNoise, noisec);
        maxNoise = Math.max(maxNoise, noisec);
      }
      noiseComplex[x + y*w] = noisec;
    }
  }

  println(String.format("noiseComplex min%6.3f max%6.3f", minNoise, maxNoise));

  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      int value = (int)((nColors - 1) * ((noiseComplex[x + y*w] - minNoise) / (maxNoise - minNoise)));
      tile[x + y*w] = value;
    }
  }

  return tile;
}

void tileStats(int[] tile) {

  int minPal = 0;
  int maxPal = 0;

  for (int i = 0; i < tile.length; i++) {
    if (i == 0) {
      minPal = maxPal = tile[i];
    } else {
      minPal = min(minPal, tile[i]);
      maxPal = max(maxPal, tile[i]);
    }
  }

  println(String.format("tile min%5d max%5d", minPal, maxPal));
}

void apply_cmdline_args() {

  if (args == null) {
    return;
  }

  for (String exp: args) {
    String[] comp = exp.split("=");
    switch (comp[0]) {
    case "file":
      filename = comp[1];
      println("use filename " + filename);
      break;
    case "exit":
      exitTimer = parseInt(comp[1], 10);
      println("exit after " + exitTimer + "s");
      break;
    }
  }
}

void check_exit() {

  if (exitTimer == 0) { // skip if not run from cmd line
    return;
  }

  int m = millis();
  if (m / 1000 >= exitTimer) {
    println(String.format("average %.1f fps", (float)frameCount / exitTimer));
    exit();
  }
}


/**
 * Saves an int array as raw data (Big Endian order)
 * to a file in the sketch folder.
 *
 * @param fname file name
 * @param data int array
 */
void saveInts(String fname, int[] data) {
  try {
    DataOutputStream ds = new DataOutputStream(new FileOutputStream(sketchPath(fname)));
    for (int i=0; i<data.length; i++) {
      ds.writeInt(data[i]);
    }
    ds.flush();
    ds.close();
  }
  catch(Exception e) {
    e.printStackTrace();
  }
}

/**
 * Loads an int array from a raw data file (Big Endian order)
 * in the sketch folder.
 *
 * @param fname file name
 * @return an int array
 */
int[] loadInts(String fname) {
  int[] data=null;
  try {
    FileInputStream fs = new FileInputStream(sketchPath(fname));
    DataInputStream ds = new DataInputStream(fs);
    data = new int[(int)(fs.getChannel().size()/4)];
    for (int i = 0; i < data.length; i++) {
      data[i] = ds.readInt();
    }
    ds.close();
    fs.close();
  }
  catch(Exception e) {
    e.printStackTrace();
  }
  return data;
}

