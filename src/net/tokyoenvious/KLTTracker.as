package net.tokyoenvious {
    import flash.display.BitmapData;

    public class KLTTracker {
        public var windowWidth:uint = 7, windowHeight:uint = 7;
        public var gradSigma:Number = 1.0;
        public var nSkippedPixels:uint = 0;
        public var minDist:uint = 10;
        public var minEigenvalue:uint = 1;

        private var sigmaLast:Number = -10.0;
        private var gaussKernel:ConvolutionKernel;
        private var gaussDerivKernel:ConvolutionKernel;

        public function selectGoodFeatures(bd:BitmapData, nCols:uint, nRows:uint, nFeatures:uint):Array {
            if (windowWidth % 2 != 1)  windowWidth++;
            if (windowHeight % 2 != 1) windowHeight++;
            if (windowWidth < 3)  windowWidth = 3;
            if (windowHeight < 3) windowHeight = 3;

            var windowHW:uint = windowWidth / 2; 
            var windowHH:uint = windowHeight / 2;

            var grad:Object = computeGradients(KLTFloatImage.fromBitmapData(bd), gradSigma);
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

        private function convolveImageHoriz(image:KLTFloatImage, kernel:ConvolutionKernel):KLTFloatImage {
            var imageOut:KLTFloatImage = image.clone();
            var radius:uint = kernel.width / 2;

            for (var y:uint = 0; y < image.nRows; y++) {
                for (var x:uint = 0; x < radius; x++) {
                    imageOut.setDataAt(x, y, 0.0);
                }
                for (; x < image.nCols - radius; x++) {
                    var sum:Number = 0.0;
                    for (var k:int = kernel.width - 1; k >= 0; k--) {
                        sum += image.getDataAt(x - radius + k, y) * kernel.data[k];
                    }
                    imageOut.setDataAt(x, y, sum);
                }
                for (; x < image.nCols; x++) {
                    imageOut.setDataAt(x, y, 0.0);
                }
            }

            return imageOut;
        }

        private function convolveImageVert(image:KLTFloatImage, kernel:ConvolutionKernel):KLTFloatImage {
            var imageOut:KLTFloatImage = image.clone();
            var radius:uint = kernel.width / 2;

            for (var x:uint = 0; x < image.nCols; x++) {
                for (var y:uint = 0; y < radius; y++) {
                    imageOut.setDataAt(x, y, 0.0);
                }
                for (; y < image.nCols - radius; y++) {
                    var sum:Number = 0.0;
                    for (var k:int = kernel.width - 1; k >= 0; k--) {
                        sum += image.getDataAt(x, y - radius + k) * kernel.data[k];
                    }
                    imageOut.setDataAt(x, y, sum);
                }
                for (; y < image.nCols; y++) {
                    imageOut.setDataAt(x, y, 0.0);
                }
            }

            return imageOut;
        }

        private function computeGradients(img:KLTFloatImage, sigma:Number):Object {
            if (Math.abs(sigma - sigmaLast) > 0.05) {
                var kernels:Object = ConvolutionKernel.computeKernels(sigma);
                gaussKernel      = kernels.gaussKernel;
                gaussDerivKernel = kernels.gaussDerivKernel;
                sigmaLast = sigma;
            }

            return {
                x: convolveSeparate(img, gaussDerivKernel, gaussKernel),
                y: convolveSeparate(img, gaussKernel, gaussDerivKernel)
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

        private function convolveSeparate(img:KLTFloatImage, horizKernel:ConvolutionKernel, vertKernel:ConvolutionKernel):KLTFloatImage {
            return convolveImageVert(convolveImageHoriz(img, horizKernel), vertKernel);
        }
    }
}

class ConvolutionKernel {
    public var width:uint;
    public var data:Array;
    public static const MAX_KERNEL_WIDTH:uint = 71;

    public function ConvolutionKernel() {
        data = new Array(MAX_KERNEL_WIDTH);
    }

    public static function computeKernels(sigma:Number):Object {
        var gauss:ConvolutionKernel      = new ConvolutionKernel;
        var gaussDeriv:ConvolutionKernel = new ConvolutionKernel;
        var factor:Number = 0.01;
        var i:int, hw:uint;

        hw = MAX_KERNEL_WIDTH / 2;
        var maxGauss:Number = 1.0, maxGaussDeriv:Number = sigma * Math.exp(-0.5);

        for (i = -hw; i <= hw; i++) {
            gauss.data[hw+i] = Math.exp(-i * i / (2 * sigma * sigma));
            gaussDeriv.data[hw+i] = -i * gauss.data[hw+i];
        }

        gauss.width = MAX_KERNEL_WIDTH;
        for (i = -hw; Math.abs(gauss.data[hw+i] / maxGauss) < factor; i++, gauss.width -= 2)
            ;
        gaussDeriv.width = MAX_KERNEL_WIDTH;
        for (i = -hw; Math.abs(gaussDeriv.data[hw+i] / maxGaussDeriv) < factor; i++, gaussDeriv.width -= 2)
            ;

        for (i = 0; i < gauss.width; i++)
            gauss.data[i] = gauss.data[i + (MAX_KERNEL_WIDTH - gauss.width) / 2];
        for (i = 0; i < gaussDeriv.width; i++)
            gaussDeriv.data[i] = gaussDeriv.data[i + (MAX_KERNEL_WIDTH - gaussDeriv.width) / 2];

        hw = gaussDeriv.width / 2;
        var den:Number;
        den = 0.0;
        for (i = 0; i < gauss.width; i++) den += gauss.data[i];
        for (i = 0; i < gauss.width; i++) gauss.data[i] /= den;
        den = 0.0;
        for (i = -hw; i <= hw; i++) den -= i * gaussDeriv.data[i+hw];
        for (i = -hw; i <= hw; i++) gaussDeriv.data[hw+i] /= den;

        return {
            gaussKernel: gauss,
            gaussDerivKernel: gaussDeriv
        };
    }
}
