package net.tokyoenvious {
    import flash.display.BitmapData;

    public class KLTTracker {
        public var gradSigma:Number = 1.0;
        public var nSkippedPixels:uint = 0;
        public var minDist:uint = 10;
        public var minEigenvalue:uint = 1;

        public var windowWidth:uint = 7, windowHeight:uint = 7;
        public var nPyramidLevels:uint = 2;
        public var subsampling:uint = 4;
        public var maxIterations:uint = 10;
        public var minDisplacement:Number = 0.1;
        public var maxResidue:Number = 1.0;
        public var minDeterminant:Number = 0.01;

        public var pyramidSigmaFact:Number = 0.9;

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

        public function trackFeatures(bd1:BitmapData, bd2:BitmapData, nCols:uint, nRows:uint, features:Array):Array {
            if (windowWidth % 2 != 1)  windowWidth++;
            if (windowHeight % 2 != 1) windowHeight++;
            if (windowWidth < 3)  windowWidth = 3;
            if (windowHeight < 3) windowHeight = 3;

            var img:KLTFloatImage;
            var image1:KLTFloatImage = KLTFloatImage.fromBitmapData(bd1);
            // image1.smooth();
            var pyramid1:KLTPyramid = new KLTPyramid(image1, nPyramidLevels, pyramidSigmaFact, subsampling);
            var pyramid1Grad:Array = new Array;
            for each (img in pyramid1.images) {
                pyramid1Grad.push(img.computeGradients(gradSigma));
            }

            var image2:KLTFloatImage = KLTFloatImage.fromBitmapData(bd2);
            var pyramid2:KLTPyramid = new KLTPyramid(image2, nPyramidLevels, pyramidSigmaFact, subsampling);
            var pyramid2Grad:Array = new Array;
            for each (img in pyramid2.images) {
                pyramid2Grad.push(img.computeGradients(gradSigma));
            }

            var newFeatures:Array = new Array;
            for each (var feature:KLTFeature in features) {
                if (feature.val < 0) {
                    newFeatures.push(feature);
                    continue;
                }

                var r:int;
                var x:Number = feature.x, y:Number = feature.y;
                for (r = nPyramidLevels - 1; r >= 0; r--) {
                    x /= subsampling, y /= subsampling;
                }

                for (r = nPyramidLevels - 1; r >= 0; r--) {
                    x *= subsampling, y *= subsampling;
                    var f:Object = trackFeature(
                        x, y,
                        pyramid1.images[r], pyramid1Grad[r].x, pyramid1Grad[r].y,
                        pyramid2.images[r], pyramid2Grad[r].x, pyramid2Grad[r].y
                    );

                    if (f.status == KLT_SMALL_DET || f.status == KLT_OOB) {
                        break;
                    }
                }

                if (f.status == KLT_OOB) {
                    newFeatures.push(new KLTFeature(-1.0, -1.0, KLT_OOB));
                /*} else if (outOfBounds(f.x, f.y, nCols, nRows, borderX, borderY)) {*/
                } else if (f.status == KLT_SMALL_DET) {
                    newFeatures.push(new KLTFeature(-1.0, -1.0, KLT_SMALL_DET));
                } else if (f.status == KLT_LARGE_RESIDUE) {
                    newFeatures.push(new KLTFeature(-1.0, -1.0, KLT_LARGE_RESIDUE));
                } else if (f.status == KLT_MAX_ITERATIONS) {
                    // XXX
                    //newFeatures.push(new KLTFeature(-1.0, -1.0, KLT_MAX_ITERATIONS));
                    newFeatures.push(feature);
                } else {
                    newFeatures.push(new KLTFeature(f.x, f.y, KLT_TRACKED));
                }
            }

            return newFeatures;
        }

        private const KLT_TRACKED:int        =  0;
        private const KLT_NOT_FOUND:int      = -1;
        private const KLT_SMALL_DET:int      = -2;
        private const KLT_MAX_ITERATIONS:int = -3;
        private const KLT_OOB:int            = -4;
        private const KLT_LARGE_RESIDUE:int  = -5;

        private function trackFeature(x1:Number, y1:Number, img1:KLTFloatImage, gradX1:KLTFloatImage, gradY1:KLTFloatImage, img2:KLTFloatImage, gradX2:KLTFloatImage, gradY2:KLTFloatImage):Object {
            const ONE_PLUS_EPS:Number = 1.001;
            var hw:uint = windowWidth / 2, hh:uint = windowHeight / 2;
            var x2:Number = x1, y2:Number = y1;
            var nc:int = img1.nCols, nr:int = img1.nRows;
            var status:int;

            var iteration:uint = 0;
            do {
                if (x1 - hw < 0.0 || nc - (x1 + hw) < ONE_PLUS_EPS ||
                    x2 - hw < 0.0 || nc - (x2 + hw) < ONE_PLUS_EPS ||
                    y1 - hh < 0.0 || nr - (y1 + hh) < ONE_PLUS_EPS ||
                    y2 - hh < 0.0 || nr - (y2 + hh) < ONE_PLUS_EPS) {
                    status = KLT_OOB;
                    break;
                }

                var imgDiff:Array = computeIntensityDifference(img1, img2, x1, y1, x2, y2);
                var grad:Object = computeGradientSum(gradX1, gradY1, gradX2, gradY2, x1, y1, x2, y2);

                var g:Object = compute2x2GradientMatrix(grad.x, grad.y);
                var e:Object = compute2x1ErrorVector(imgDiff, grad.x, grad.y);

                var o:Object = solveEquation(g.xx, g.xy, g.yy, e.x, e.y);
                if (o.status == KLT_SMALL_DET) {
                    break;
                }
                status = o.status;
                x2 += o.dx, y2 += o.dy;
                iteration++;
            } while ((Math.abs(o.dx) >= minDisplacement || Math.abs(o.dy) >= minDisplacement) && iteration < maxIterations);

            if (x2 - hw < 0.0 || nc - (x2 + hw) < ONE_PLUS_EPS ||
                y2 - hh < 0.0 || nr - (y2 + hh) < ONE_PLUS_EPS) {
                status = KLT_OOB;
            }

            if (status == KLT_TRACKED) {
                imgDiff = computeIntensityDifference(img1, img2, x1, y1, x2, y2);
                if (sumAbsFloatWindow(imgDiff) / (windowWidth * windowHeight) > maxResidue) {
                    status = KLT_LARGE_RESIDUE;
                }
            }

            return {
                status: iteration >= maxIterations ? KLT_MAX_ITERATIONS : status,
                x: x2,
                y: y2
            };
        }

        private function compute2x2GradientMatrix(gradX:Array, gradY:Array):Object {
            var gxx:Number = 0.0, gxy:Number = 0.0, gyy:Number = 0.0;

            for (var i:int = 0; i < gradX.length; i++) {
                var gx:Number = gradX[i], gy:Number = gradY[i];
                gxx += gx * gx;
                gxy += gx * gy;
                gyy += gy * gy;
            }

            return {
                xx: gxx,
                xy: gxy,
                yy: gyy
            };
        }

        private function compute2x1ErrorVector(imgDiff:Array, gradX:Array, gradY:Array):Object {
            var ex:Number = 0.0, ey:Number = 0.0;
            for (var i:int = 0; i < imgDiff.length; i++) {
                var diff:Number = imgDiff[i];
                ex += diff * gradX[i];
                ey += diff * gradY[i];
            }

            return {
                x: ex,
                y: ey
            };
        }

        private function solveEquation(gxx:Number, gxy:Number, gyy:Number, ex:Number, ey:Number):Object {
            var det:Number = gxx * gyy - gxy * gxy;
            if (det < minDeterminant) {
                return {
                    status: KLT_SMALL_DET
                };
            }

            return {
                status: KLT_TRACKED,
                dx: (gyy * ex - gxy * ey) / det,
                dy: (gxx * ey - gxy * ex) / det
            };
        }

        private function sumAbsFloatWindow(fw:Array):Number {
            var sum:Number = 0.0;

            var i:int = 0;
            for (var h:int = windowHeight; h > 0; h--) {
                for (var w:int = 0; w < windowWidth; w++) {
                    sum += Math.abs(fw[i++]);
                }
            }

            return sum;
        }

        private function computeIntensityDifference(img1:KLTFloatImage, img2:KLTFloatImage, x1:Number, y1:Number, x2:Number, y2:Number):Array {
            var imgDiff:Array = new Array;
            var hw:int = windowWidth / 2, hh:int = windowHeight / 2;

            for (var j:int = -hh; j <= hh; j++) {
                for (var i:int = -hw; i < hw; i++) {
                    imgDiff.push(img1.getInterpolatedData(x1 + i, y1 + j) - img2.getInterpolatedData(x2 + i, y2 + j));
                }
            }

            return imgDiff;
        }

        private function computeGradientSum(gradX1:KLTFloatImage, gradY1:KLTFloatImage, gradX2:KLTFloatImage, gradY2:KLTFloatImage, x1:Number, y1:Number, x2:Number, y2:Number):Object {
            var gradX:Array = new Array, gradY:Array = new Array;
            var hw:int = windowWidth / 2, hh:int = windowHeight / 2;

            for (var j:int = -hh; j <= hh; j++) {
                for (var i:int = -hw; i <= hw; i++) {
                    gradX.push(gradX1.getInterpolatedData(x1 + i, y1 + j) + gradX2.getInterpolatedData(x2 + i, y2 + j));
                    gradY.push(gradY1.getInterpolatedData(x1 + i, y1 + j) + gradY2.getInterpolatedData(x2 + i, y2 + j));
                }
            }

            return {
                x: gradX,
                y: gradY
            };
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
