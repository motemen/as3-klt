package net.tokyoenvious {
    import flash.display.BitmapData;
    public class KLTTracker {
        public var windowWidth:uint = 7, windowHeight:uint = 7;
        public var gradSigma:Number = 1.0;
        public var nSkippedPixels:uint = 0;
        public var mindist:uint = 10;

        private var sigmaLast:Number = -10.0;
        private var gaussKernel:ConvolutionKernel;
        private var gaussderivKernel:ConvolutionKernel;

        public function KLTTracker() {
        }

        public function selectGoodFeatures(bd:BitmapData, nCols:uint, nRows:uint):Array {
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
                trace('limit: ' + limit);
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
                        var val:Number = minEigenvalue(gxx, gxy, gyy);
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
            /*
            _enforceMinimumDistance(
                pointlist,
                npoints,
                featurelist,
                ncols, nrows,
                mindist,
                min_eigenvalue,
                overwriteAllFeatures
            );
            */
            return points;
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
        private function minEigenvalue(gxx:Number, gxy:Number, gyy:Number):Number {
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

import flash.display.BitmapData;
class KLTFloatImage {
    public var nCols:uint;
    public var nRows:uint;
    public var data:Array;
    public function KLTFloatImage(cols:uint, rows:uint) {
        nCols = cols;
        nRows = rows;
        data = new Array(nCols * nRows);
    }
    public function getDataAt(x:uint, y:uint):Number {
        return data[y * nCols + x];
    }
    public function setDataAt(x:uint, y:uint, value:Number):void {
        data[y * nCols + x] = value;
    }
    public function clone():KLTFloatImage {
        var image:KLTFloatImage = new KLTFloatImage(nCols, nRows);
        image.nCols = nCols;
        image.nRows = nRows;
        image.data  = data.slice();
        return image;
    }
    public static function fromBitmapData(bd:BitmapData):KLTFloatImage {
        var image:KLTFloatImage = new KLTFloatImage(bd.width, bd.height);
        for (var y:uint = 0; y < bd.height; y++) {
            for (var x:uint = 0; x < bd.width; x++) {
                var rgb:uint = bd.getPixel(x, y);
                image.data[y * bd.width + x] = (((rgb & 0xFF0000) >> 16) + ((rgb & 0x00FF00) >> 8) + (rgb & 0x0000FF)) / 3
            }
        }
        return image;
    }
}
