import processing.svg.*;
import java.util.*;

MCorner[][] corners;
color [][] center;
int[][] domCount;

PImage test;

void setup(){
  size(1000, 400);
  
  
  noSmooth();
  background(0);
  
  if (args != null) {
    if (args[0].toLowerCase() == "help" || args.length % 2 != 0) {
      print("Marching Squares\nUsage: ms INPUT OUTPUT");
      exit(); // doesnt immediately terminate, so else clause needed
    } else {
      for (int i = 0; i < args.length / 2; i++) {
        try {
          generateSVG(args[i * 2], args[i * 2 + 1]);
        } catch (Exception e) {
          print("generating " + args[i * 2] + " to " + args[i * 2 + 1] + " failed with exception: \n" + e + "\n");
          exit();
          break;
        }
      }
      exit();
    }
  } else {
    File f = new File(dataPath(""));
    for (var file:f.listFiles()) {
      if (file.getName().contains(".png")) {
        String[] dvd = file.getAbsolutePath().split("/");
        generateSVG(file.getAbsolutePath(), "output/" +dvd[dvd.length-1].split("\\.")[0] + ".svg");
      }
  }
}
  
  //todo:
  // add contour cases for image edges within cells [x]
  // generate contour from cells [x]
     // - create contour polygons [x]
     // - decimate useless vertexes.
     // - create hierachy of polygon being 'enclosed' in other polygons for holes and polygons within polygons
        // - some kind of color flood approach?
     // - finally draw clean polygon with appropriate backward contours for holes
   // export to svg [x]
   

}

void draw() {}

void generateSVG(String imageloc, String imageout){
  test = loadImage(imageloc);
  test.loadPixels();

  corners = new MCorner[test.width][test.height];
  center = new color[corners.length-1][corners[0].length-1];
  domCount = new int[center.length][center[0].length];
  BorderedImage bimg = new BorderedImage(test);
  for (int i = 0; i<test.pixels.length; i++) {
    int x = i % test.width;
    int y = i / test.width;
    corners[x][y] = new MCorner(bimg, x, y);
  }
  MCorner quad[] = new MCorner[4];
  for (int x = 0; x<test.width-1; x++) {
    for (int y = 0; y<test.height-1; y++) {
      for (int z = 0; z<4; z++) {
        int forw = (z+3)%4;
        quad[z] = corners[x+corner[forw][0]][y+corner[forw][1]];
      }
      center[x][y] = getDominant(quad);
      domCount[x][y] = countMostFrequentColor(quad);
    }
  }
  float scl = 1;
  //drawSquares(scl,corners,test,center,domCount);
  fill(0,100);
  rect(0,0,width,height);
  
  var cells = generateCells(scl,corners,test,center,domCount);
  PGraphics svg = createGraphics(test.width, test.height, SVG, imageout);
  svg.beginDraw();
  svg.noStroke();
  boolean[][] mapped = new boolean[test.width][test.height];
  for (int x = 0; x<test.width-1; x++) {
    for (int y = 0; y<test.height-1; y++) {
      if(!mapped[x][y] && cells[x][y].hasRoute && alpha(test.pixels[x+y*test.width])>0){
        var contour = getContour(cells,x,y,test.pixels[x+y*test.width],mapped);
        if(contour!=null){
           contour.draw(svg,scl);
           contour.draw(g,scl);
           
        }
      }
    }
  }
  svg.dispose();
  svg.endDraw();
  //image(svg,0,0);
  translate(test.width,0);
}


Contour getContour(MSCell[][] cells, int x,int y, color c, boolean[][] mapped){
  var origin = cells[x][y];
  var current = origin;
  int cdir = -1;
  for(int i = 0;i<4;i++){
    if(origin.route[i]!=-1 && origin.corners[(i+3)%4].c == c){
      cdir = i;
    }
  }
  if(cdir==-1){
    return null;
  }
  int l = 0;
  ArrayList<PVector> contour = new ArrayList();
  while(true){
    contour.add(current.getVert(cdir));
    if(current == origin && l>1){
      break;
    }
    if(current.routeStops[cdir]!=null){
      contour.addAll(Arrays.asList(current.routeStops[cdir]));
    }
    
    for(int i = 0;i<4;i++){
      if(current.corners[i].c == c){
        mapped[current.corners[i].x][current.corners[i].y] = true;
      }
    }
    cdir = current.route[cdir];
    
    if(cdir==-1){
      break;
    }
    //we went out of bound so traverse edge until we find a way back
    if(!inBounds(current.x ,current.y ,cdir ,cells)){
      int ax = current.x + dir[cdir][0];
      int ay = current.y + dir[cdir][1];
      contour.add(current.getAntiVert(cdir));
      int dd = getBoundsDir(ax,ay,cells.length,cells[0].length);
      while(true){
        ax+= dir[dd][0];
        ay+= dir[dd][1];
        if(inBounds(ax ,ay ,(dd+1)%4 ,cells)){
          var candidate = cells[ax + dir[(dd+1)%4][0]][ay + dir[(dd+1)%4][1]];
          if(candidate.hasRoute && candidate.route[(dd+1)%4]!=-1){
            current=candidate;
            cdir=(dd+1)%4;
            break;
          }
        }
        int pd = dd;
        dd = getBoundsDir(ax,ay,cells.length,cells[0].length);
        if(dd!=pd){
          contour.add(new PVector(constrain(ax,0,cells.length)+0.5,constrain(ay,0,cells.length)+0.5));
        }
      }
    }else{
      current = cells[current.x + dir[cdir][0]][current.y + dir[cdir][1]];
    }
    l++;
  }
  
  ArrayList<PVector> lcontour = new ArrayList();
  for(int i = 0;i<contour.size();i++){
    PVector prev = contour.get((i+contour.size()-1)%contour.size());
    PVector curr = contour.get(i);
    if(prev.dist(curr)<0.01 ){
      continue;
    }
    lcontour.add(contour.get(i));
  }
  
  ArrayList<PVector> decimatedcontour = new ArrayList();
  for(int i = 0;i<lcontour.size();i++){
    PVector prev = lcontour.get((i+lcontour.size()-1)%lcontour.size());
    PVector curr = lcontour.get(i);
    PVector next = lcontour.get((i+1)%lcontour.size());
    if(PVector.sub(curr,prev).normalize().dot(PVector.sub(next,curr).normalize()) < 0.9){
      decimatedcontour.add(lcontour.get(i));
    }
  }
  
  return new Contour(decimatedcontour,c);

}

int getBoundsDir(int x,int y, int w,int h){
  if(y==-1 && x!= w){
    return 0;
  }
  if(y!=h && x== w){
    return 1;
  }
  if(y==h && x!= -1){
    return 2;
  }
  if(y!=-1 && x== -1){
    return 3;
  }
  return -1;
}

class Contour{
  color c;
  ArrayList<PVector> contour = new ArrayList();
  Contour(ArrayList<PVector> contour, color c){
    this.contour = contour;
    this.c=c;
  }
  
  void draw(PGraphics pg, float scl){
    pg.fill(c);
    pg.noStroke();
    pg.beginShape(POLYGON);
    
    for(var v:contour){
      pg.vertex(v.x*scl,v.y*scl);
    }
    pg.endShape(CLOSE);
  }
}
