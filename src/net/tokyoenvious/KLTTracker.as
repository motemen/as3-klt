package net.tokyoenvious {
    import flash.display.BitmapData;

    public class KLTTracker {
        public var windowWidth:uint, windowHeight:uint;
        public var gradSigma:Number;

        private var sigmaLast:Number;

        private var gaussKernel:ConvolutionKernel;
        private var gaussderivKernel:ConvolutionKernel;

        public function KLTTracker() {
        }

        public function selectGoodFeatures(bd:BitmapData, nCols:uint, nRows:uint):void {
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

            var imgTemp:KLTFloatImage  = KLTFloatImage.fromBitmapData(bd);
            var imgGradX:KLTFloatImage = imgTemp.clone();
            var imgGradY:KLTFloatImage = imgTemp.clone();

            var grads:Object = computeGradients(imgTemp, gradSigma);
        }

        private function convolveImageHoriz(image:KLTFloatImage, kernel:ConvolutionKernel):KLTFloatImage {
            var imageOut:KLTFloatImage = image.clone();
            var radius:uint = kernel.width / 2;
            for (var y:uint = 0; y < image.nRows; y++) {
                for (var x:uint = 0; x < radius; x++) {
                    imageOut.setDataAt(x, y, 0.0);
                }
                for ( ; x < image.nCols - radius; x++) {
                    var sum:Number = 0.0;
                    for (var k:uint = kernel.width - 1; k >= 0; k--) {
                        sum += image.getDataAt(x - radius + k, y) * kernel.data[k];
                    }
                    imageOut.setDataAt(x, y, sum);
                }
                for ( ; x < image.nCols; x++) {
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
                for ( ; y < image.nCols - radius; y++) {
                    var sum:Number = 0.0;
                    for (var k:uint = kernel.width - 1; k >= 0; k--) {
                        sum += image.getDataAt(x, y - radius + k) * kernel.data[k];
                    }
                    imageOut.setDataAt(x, y, sum);
                }
                for ( ; y < image.nCols; y++) {
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

        private function convolveSeparate(img:KLTFloatImage, horizKernel:ConvolutionKernel, vertKernel:ConvolutionKernel):KLTFloatImage {
            return convolveImageVert(convolveImageHoriz(img, horizKernel), vertKernel);
        }
    }
}

class ConvolutionKernel {
    public var width:uint;
    public var data:Array;

    public static const MAX_KERNEL_WIDTH:uint = 71;

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
            for (i = -hw; i <= hw ; i++) {
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
        for (i = 0 ; i < gauss.width ; i++)
            gauss.data[i] = gauss.data[i + (MAX_KERNEL_WIDTH - gauss.width) / 2];
        for (i = 0 ; i < gaussderiv.width ; i++)
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
        image.data  = data.clone();
        return image;
    }

    public static function fromBitmapData(bd:BitmapData):KLTFloatImage {
        var image:KLTFloatImage = new KLTFloatImage(bd.width, bd.height);
        for (var y:uint = 0; y < bd.height; y++) {
            for (var x:uint = 0; x < bd.width; x++) {
                image.data[y * bd.width + x] = Number(bd.getPixel(x, y));
            }
        }
        return image;
    }
}
