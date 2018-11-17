// Main class: Mandelbrot
// Project type: applet
// Arguments: 
// Compile command: javac -g -deprecation
import java.applet.*;
import java.awt.*;
import java.awt.event.*;

public class Mandelbrot extends Applet implements MouseListener
{
 
  private double midX, midY, range;
  

  public void init()
  {
    midX = 0;//-0.25;
    midY = 0;//.85;
    range = 2;//0.004;
    this.addMouseListener(this);
  }

  public void mousePressed(MouseEvent e)
  {
	  int nWidth=getWidth()/2;
	  int nHeight=getHeight()/2;
    midX += (((e.getX()-nWidth) * range)/nWidth);
    midY += (((nHeight- e.getY()) * range)/nHeight);
    switch(e.getButton())
    {
    case 1:
    	range /=2;
    	break;
    case 2:
    	range *=3;
    	break;
    }
    Graphics g = getGraphics();
    paint(g);
  }

  public void paint(Graphics g)
  { 
	  int nWidth=getWidth();
	  int nHeight=getHeight();
	  int h2=nHeight/2;
	  int w2=nWidth/2;
    Rectangle ClipClop = g.getClipBounds();
// I Paint first in crude 16*16 blocks and then
// in finer and finer tiles. This is so that
// SOMETHING appears on the screen rather rapidly.
    /*for (*/int resolution/*=16; resolution>*/=1;/* resolution/=2)*/
    {
      for (int y=0; y<=nHeight; y+=resolution)
	for (int x=0; x<=nWidth; x+=resolution)
	  {
	    //if (ClipClop.contains(x,(nWidth - y))) 
 // Does it need to redraw?
	    {
	      int n = 0;
	      int LIMIT = 250; // Maybe adjust this?
	      Complex z = new Complex(0.0, 0.0);
	      Complex c =new Complex((range*(x-w2))/w2 + midX,
				     (range*(y-h2))/h2 + midY);
// Important loop follows.
	      while (n++ < LIMIT && z.modulus() < 4.0)
		{ z = z.times(z); // z = z * z;
		z = z.plus(c); // z = z + c;
		}
// Draw in black in count overflowed
	      if (n >= LIMIT) g.setColor(Color.black);
// ... otherwise select a colo(u)r based on
// the Hue/Saturation/Brightness colour model.
// This gives me a nice rainbow effect. If
// your display only supports 256 (or fewer)
// colours it will not be so good.
	      else g.setColor(Color.getHSBColor(
// cycle HUE as n goes from 0 to 64
						(float)(n % 64)/64.0f,
// vary saturation from 0.2 to 1.0 as n varies
						(float)(0.6+0.4*
							Math.cos((double)n/40.0)),
// leave brightness at 1.0
						1.0f));
// screen coords point y downwards, so flip to
// agree with norman human conventions.
	      g.fillRect(x, nHeight-y, // posn
			 resolution, resolution); // size
	    }
	  }
    }
  }
  
  public void mouseReleased(MouseEvent e){};
  public void mouseClicked(MouseEvent e){};
  public void mouseEntered(MouseEvent e){};
  public void mouseExited(MouseEvent e){};
  
}

class Complex  // Complex numbers
{
  private double x, y;
  public Complex(double realPart, double imagPart)
  {
    x = realPart;
    y = imagPart;
  }
  public double modulus()
  { 
    return Math.sqrt(x*x+y*y);
  }
  public Complex plus(Complex a)
  { 
    return new Complex(x + a.x, y + a.y);
  }
  public Complex times(Complex a)
  { 
    return new Complex(x*a.x - y*a.y,
		       x*a.y + y*a.x);
  }
}


