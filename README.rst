===============
    as3-klt
===============

as3-klt is a library for image feature detection/tracking based on `KLT <http://www.ces.clemson.edu/~stb/klt/>`_, a C library.

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

``trackFeatures(bd1:BitmapData, bd2:BitmapData, nCols:uint, nRows:uint, features:Array):Array``
  Tracks ``features`` in image ``bd1`` of size ``nCols`` x ``nRows`` and returns their new positions in ``bd2``.

``net.tokyoenvious.KLTFeature``
'''''''''''''''''''''''''''''''

Represents a detected feature point.

``x``, ``y``
  Feature's position.

``val``
  (selectGoodFeatures) Feature's score.
  (trackFeatures) Feature's status.

``net.tokyoenvious.KLTFloatImage``
''''''''''''''''''''''''''''''''''

Used internally. Has value of type ``Number`` on each pixel.

``net.tokyoenvious.KLTPyramid``
'''''''''''''''''''''''''''''''

Used internally. Represents pyramid of ``KLTFloatImage``.

--------
  TODO
--------

* Impletement sequential mode
* Accept tracking region as ``Rectangle``
* Simplify code
