package net.tokyoenvious {
    import flash.display.BitmapData;

    public class KLTTracker {
        public var windowWidth:uint = 7, windowHeight:uint = 7;
        public var gradSigma:Number = 1.0;
        public var nSkippedPixels:uint = 0;
        public var mindist:uint = 10;
        public var minEigenvalue:uint = 1;

        private var sigmaLast:Number = -10.0;
        private var gaussKernel:ConvolutionKernel;
        private var gaussderivKernel:ConvolutionKernel;

        public function KLTTracker() {
        }

        public function selectGoodFeatures(bd:BitmapData, nCols:uint, nRows:uint, nFeatures:uint):Array {
            if (windowWidth % 2 != 1) {
                windowWidth++;
            }
            if (windowHeight % 2 != 1) {
                windowHeight++;
            }
            if (windowWidth < 3) {
                windowWidth = 3;
            }
            if (windowHeight < 3) {
                windowHeight = 3;
            }
            var windowHW:uint = windowWidth / 2; 
            var windowHH:uint = windowHeight / 2;

            var imgTemp:KLTFloatImage = KLTFloatImage.fromBitmapData(bd);
            var grads:Object = computeGradients(imgTemp, gradSigma);

            {
                var points:Array = [];
                var limit:int = (1 << 16) - 1;
                var borderX:int = borderX;	/* Must not touch cols */
                var borderY:int = borderY;	/* lost by convolution */
                if (borderX < windowHW) borderX = windowHW;
                if (borderY < windowHH) borderY = windowHH;

                /* For most of the pixels in the image, do ... */
                for (var y:int = borderY; y < nRows - borderY; y += (nSkippedPixels + 1)) {
                    for (var x:int = borderX; x < nCols - borderX; x += (nSkippedPixels + 1)) {
                        /* Sum the gradients in the surrounding window */
                        var gxx:Number = 0, gxy:Number = 0, gyy:Number = 0;
                        for (var yy:int = y - windowHH; yy <= y + windowHH; yy++) {
                            for (var xx:int = x - windowHW; xx <= x + windowHW; xx++) {
                                var gx:Number = grads.x.getDataAt(xx, yy);
                                var gy:Number = grads.y.getDataAt(xx, yy);
                                gxx += gx * gx;
                                gxy += gx * gy;
                                gyy += gy * gy;
                            }
                        }
                        /* Store the trackability of the pixel as the minimum
                           of the two eigenvalues */
                        var val:Number = calcMinEigenvalue(gxx, gxy, gyy);
                        //trace([gxx, gxy, gyy]);
                        //trace(val);
                        if (val != 0) {
                            //trace('vala: ' + val);
                        }
                        if (val > limit) {
                            /*
                            KLTWarning("(_KLTSelectGoodFeatures) minimum eigenvalue %f is "
                                    "greater than the capacity of an int; setting "
                                    "to maximum value", val);
                            */
                            val = limit;
                        }
                        if (val != 0) {
                            //trace('valb: ' + val);
                        }
                        points.push({ x: x, y: y, val: val });

                    }
                }
            }

            /* Sort the features */
            //points.sort(function (a:Object, b:Object):int { return a.val < b.val ? -1 : a.val > b.val ? +1 : 0 });
            points.sort(function (a:Object, b:Object):int { return a.val < b.val ? +1 : a.val > b.val ? -1 : 0 });
            trace('sorted');
            /* Check tc->mindist */
            /*
            if (mindist < 0) {
                KLTWarning("(_KLTSelectGoodFeatures) Tracking context field tc->mindist "
                        "is negative (%d); setting to zero", tc->mindist);
                mindist = 0;
            }
            */

            /* Enforce minimum distance between features */
            return enforceMinimumDistance(
                points,
                nCols, nRows,
                mindist,
                minEigenvalue,
                nFeatures
            );
        }
        private function convolveImageHoriz(image:KLTFloatImage, kernel:ConvolutionKernel):KLTFloatImage {
            var imageOut:KLTFloatImage = image.clone();
            var radius:uint = kernel.width / 2;
            var _:int = 0;
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
            /* Output images must be large enough to hold result */
            //assert(gradx->ncols >= img->ncols);
            //assert(gradx->nrows >= img->nrows);
            //assert(grady->ncols >= img->ncols);
            //assert(grady->nrows >= img->nrows);
            /* Compute kernels, if necessary */
            if (Math.abs(sigma - sigmaLast) > 0.05) {
                var kernels:Object = ConvolutionKernel.computeKernels(sigma);
                gaussKernel      = kernels.gaussKernel;
                gaussderivKernel = kernels.gaussderivKernel;
                sigmaLast = sigma;
            }
            return {
                x: convolveSeparate(img, gaussderivKernel, gaussKernel),
                y: convolveSeparate(img, gaussKernel, gaussderivKernel)
            };
        }
        private function enforceMinimumDistance(points:Array, nCols:int, nRows:int, mindist:int, minEigenvalue:int, nFeatures:int):Array {
            var index:int;/* Index into features */
            var x:int, y:int, val:int;/* Location and trackability of pixel under consideration */
            var featuremap:Array = new Array(nCols * nRows);
            var features:Array = new Array(nFeatures);

            /* Cannot add features with an eigenvalue less than one */
            if (minEigenvalue < 1) minEigenvalue = 1;

            /* Necessary because code below works with (mindist-1) */
            mindist--;

            /* If we are keeping all old good features, then add them to the featuremap */
            /*
            if (!overwriteAllFeatures)
                for (index = 0 ; index < featurelist->nFeatures ; index++)
                    if (featurelist->feature[index]->val >= 0)  {
                        x   = (int) featurelist->feature[index]->x;
                        y   = (int) featurelist->feature[index]->y;
                        _fillFeaturemap(x, y, featuremap, mindist, ncols, nrows);
                    }
            */

            /* For each feature point, in descending order of importance, do ... */
            index = 0;
            for each (var point:Object in points) {
                /* If we can't add all the points, then fill in the rest
                   of the featurelist with -1's */
                if (index >= points.length) {
                    while (index < nFeatures)  {
                        if (features[index].val < 0) {
                            features[index] = new KLTFeature(-1, -1, KLTFeature.KLT_NOT_FOUND);
                        }
                        index++;
                    }
                    break;
                }

                /* Ensure that feature is in-bounds */
                /*
                assert(x >= 0);
                assert(x < ncols);
                assert(y >= 0);
                assert(y < nrows);
                */

                while (index < nFeatures && features[index] && features[index].val >= 0) {
                    index++;
                }

                if (index >= nFeatures) {
                    break;
                }

                /* If no neighbor has been selected, and if the minimum
                   eigenvalue is large enough, then add feature to the current list */
                trace('featuremap: ' + point.x + ',' + point.y + ':' + featuremap[point.y * nCols + point.x]);
                if (!featuremap[point.y * nCols + point.x] && point.val >= minEigenvalue)  {
                    features[index++] = new KLTFeature(point.x, point.y, point.val);
                    trace(features[index-1]);

                    /* Fill in surrounding region of feature map, but
                       make sure that pixels are in-bounds */
                    fillFeaturemap(point.x, point.y, featuremap, mindist, nCols, nRows);
                }
            }
            trace(features[0].x + ',' + features[0].y);

            return features;
        }
        private function fillFeaturemap(x:int, y:int, featuremap:Array, mindist:int, nCols:int, nRows:int):void {
            for (var iy:int = y - mindist ; iy <= y + mindist ; iy++)
                for (var ix:int = x - mindist ; ix <= x + mindist ; ix++)
                    if (ix >= 0 && ix < nCols && iy >= 0 && iy < nRows)
                        featuremap[iy * nCols + ix] = true;
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
        var gaussderiv:ConvolutionKernel = new ConvolutionKernel;
        var factor:Number = 0.01; /* for truncating tail */
        var i:int, hw:uint;
        //assert(MAX_KERNEL_WIDTH % 2 == 1);
        //assert(sigma >= 0.0);
        /* Compute kernels, and automatically determine widths */
        {
            hw = MAX_KERNEL_WIDTH / 2;
            var maxGauss:Number = 1.0, maxGaussderiv:Number = sigma * Math.exp(-0.5);
            /* Compute gauss and deriv */
            for (i = -hw; i <= hw; i++) {
                gauss.data[hw+i] = Math.exp(- i*i / (2 * sigma * sigma));
                gaussderiv.data[hw+i] = -i * gauss.data[hw+i];
            }
            /* Compute widths */
            gauss.width = MAX_KERNEL_WIDTH;
            for (i = -hw; Math.abs(gauss.data[hw+i] / maxGauss) < factor; 
                    i++, gauss.width -= 2)
                ;
            gaussderiv.width = MAX_KERNEL_WIDTH;
            for (i = -hw; Math.abs(gaussderiv.data[hw+i] / maxGaussderiv) < factor; 
                    i++, gaussderiv.width -= 2)
                ;
            //if (gauss.width == MAX_KERNEL_WIDTH || 
            //        gaussderiv.width == MAX_KERNEL_WIDTH)
            //    KLTError("(_computeKernels) MAX_KERNEL_WIDTH %d is too small for "
            //            "a sigma of %f", MAX_KERNEL_WIDTH, sigma);
        }
        /* Shift if width less than MAX_KERNEL_WIDTH */
        for (i = 0; i < gauss.width; i++)
            gauss.data[i] = gauss.data[i + (MAX_KERNEL_WIDTH - gauss.width) / 2];
        for (i = 0; i < gaussderiv.width; i++)
            gaussderiv.data[i] = gaussderiv.data[i + (MAX_KERNEL_WIDTH - gaussderiv.width) / 2];
        /* Normalize gauss and deriv */
        {
            hw = gaussderiv.width / 2;
            var den:Number;
            den = 0.0;
            for (i = 0; i < gauss.width;i++) den += gauss.data[i];
            for (i = 0; i < gauss.width;i++) gauss.data[i] /= den;
            den = 0.0;
            for (i = -hw; i <= hw; i++) den -= i * gaussderiv.data[i+hw];
            for (i = -hw; i <= hw; i++) gaussderiv.data[hw+i] /= den;
        }
        //sigma_last = sigma;
        return {
            gaussKernel: gauss,
            gaussderivKernel: gaussderiv
        };
    }
}
