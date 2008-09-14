===============
    as3-klt
===============

as3-klt is a library for image feature tracking/detection based on `KLT <http://www.ces.clemson.edu/~stb/klt/>`_, a C library.

------------
  Synopsis
------------
::

  var bd:BitmapData = new BitmapData(image.width, image.height);
  bd.draw(image);

  var g:Graphics = canvas.graphics;
  g.beginBitmapFill(bd);
  g.drawRect(0, 0, bd.width, bd.height);
  g.endFill();
  g.lineStyle(1, 0xFF0000);

  var tracker:KLTTracker = new KLTTracker;
  var features:Array = tracker.selectGoodFeatures(bd, image.width, image.height, 20);
  for each (var p:KLTFeature in features) {
      g.drawCircle(p.x, p.y, 2);
  }

-----------
  Classes
-----------

``net.tokyoenvious.KLTTracker``
'''''''''''''''''''''''''''''''

Contains feature-tracking context.

``selectGoodFeatures(bd:BitmapData, nCols:uint, nRows:uint, nFeatures:int):Array``
  Finds and returns ``nFeatures`` feature points in an image ``bd`` of size ``nCols`` x ``nRows``.

``net.tokyoenvious.KLTFeature``
'''''''''''''''''''''''''''''''

Represents a detected feature point.

``x``, ``y``
  Feature's position.

``val``
  Feature's score.

``net.tokyoenvious.KLTFloatImage``
''''''''''''''''''''''''''''''''''

Used internally. Has value of type ``Number`` on each pixel.

``net.tokyoenvious.KLTConvolutionKernel``
'''''''''''''''''''''''''''''''''''''''''

Used internally.

--------
  TODO
--------

* **Write feature-tracking code**
* Simplify code
