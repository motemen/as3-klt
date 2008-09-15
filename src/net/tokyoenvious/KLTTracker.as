package net.tokyoenvious {
    import flash.display.BitmapData;

    public class KLTTracker {
        public var windowWidth:uint = 7, windowHeight:uint = 7;
        public var gradSigma:Number = 1.0;
        public var nSkippedPixels:uint = 0;
        public var minDist:uint = 10;
        public var minEigenvalue:uint = 1;

        private var sigmaLast:Number = -10.0;

        public function selectGoodFeatures(bd:BitmapData, nCols:uint, nRows:uint, nFeatures:uint):Array {
            if (windowWidth % 2 != 1)  windowWidth++;
            if (windowHeight % 2 != 1) windowHeight++;
            if (windowWidth < 3)  windowWidth = 3;
            if (windowHeight < 3) windowHeight = 3;

            var windowHW:uint = windowWidth / 2; 
            var windowHH:uint = windowHeight / 2;

            var grad:Object = KLTFloatImage.fromBitmapData(bd).computeGradients(gradSigma);
            var gradX:KLTFloatImage = grad.x, gradY:KLTFloatImage = grad.y;

            var points:Array = [];
            var limit:int = (1 << 16) - 1;
            var borderX:int = borderX, borderY:int = borderY;
            if (borderX < windowHW) borderX = windowHW;
            if (borderY < windowHH) borderY = windowHH;

            for (var y:int = borderY; y < nRows - borderY; y += (nSkippedPixels + 1)) {
                for (var x:int = borderX; x < nCols - borderX; x += (nSkippedPixels + 1)) {
                    var gxx:Number = 0, gxy:Number = 0, gyy:Number = 0;
                    for (var yy:int = y - windowHH; yy <= y + windowHH; yy++) {
                        for (var xx:int = x - windowHW; xx <= x + windowHW; xx++) {
                            var gx:Number = gradX.getDataAt(xx, yy);
                            var gy:Number = gradY.getDataAt(xx, yy);
                            gxx += gx * gx;
                            gxy += gx * gy;
                            gyy += gy * gy;
                        }
                    }

                    var val:Number = Math.min(calcMinEigenvalue(gxx, gxy, gyy), limit);
                    points.push({ x: x, y: y, val: val });
                }
            }

            points.sort(function (a:Object, b:Object):int { return a.val < b.val ? +1 : a.val > b.val ? -1 : 0 });

            return enforceMinimumDistance(
                points,
                nCols, nRows,
                minDist,
                minEigenvalue,
                nFeatures
            );
        }

        private function enforceMinimumDistance(points:Array, nCols:int, nRows:int, minDist:int, minEigenvalue:int, nFeatures:int):Array {
            var index:int = 0;
            var x:int, y:int, val:int;
            var featureMap:Array = new Array(nCols * nRows);
            var features:Array = new Array(nFeatures);

            if (minEigenvalue < 1) minEigenvalue = 1;

            minDist--;

            for each (var point:Object in points) {
                if (index >= points.length) {
                    while (index < nFeatures)  {
                        if (features[index].val < 0) {
                            features[index] = new KLTFeature(-1, -1, KLTFeature.KLT_NOT_FOUND);
                        }
                        index++;
                    }
                    break;
                }

                while (index < nFeatures && features[index] && features[index].val >= 0) {
                    index++;
                }

                if (index >= nFeatures) {
                    break;
                }

                if (!featureMap[point.y * nCols + point.x] && point.val >= minEigenvalue)  {
                    features[index++] = new KLTFeature(point.x, point.y, point.val);
                    fillFeaturemap(point.x, point.y, featureMap, minDist, nCols, nRows);
                }
            }

            return features;
        }

        private function fillFeaturemap(x:int, y:int, featureMap:Array, minDist:int, nCols:int, nRows:int):void {
            for (var iy:int = y - minDist ; iy <= y + minDist ; iy++)
                for (var ix:int = x - minDist ; ix <= x + minDist ; ix++)
                    if (ix >= 0 && ix < nCols && iy >= 0 && iy < nRows)
                        featureMap[iy * nCols + ix] = true;
        }

        private function calcMinEigenvalue(gxx:Number, gxy:Number, gyy:Number):Number {
            return (gxx + gyy - Math.sqrt((gxx - gyy) * (gxx - gyy) + 4 * gxy * gxy)) / 2.0;
        }
    }
}
