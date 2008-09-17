package net.tokyoenvious {
    import flash.display.BitmapData;

    public class KLTFloatImage {
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

        public function getInterpolatedData(x:Number, y:Number):Number {
            var xt:int = int(x), yt:int = int(y);
            var ax:Number = x - xt, ay:Number = y - yt;

            return (1 - ax) * (1 - ay) * getDataAt(xt,     yt    )
                 +      ax  * (1 - ay) * getDataAt(xt + 1, yt    )
                 + (1 - ax) *      ay  * getDataAt(xt,     yt + 1)
                 +      ax  *      ay  * getDataAt(xt + 1, yt + 1);
        }

        public function clone():KLTFloatImage {
            var image:KLTFloatImage = new KLTFloatImage(nCols, nRows);
            image.data  = data.slice();
            return image;
        }

        public static function fromBitmapData(bd:BitmapData):KLTFloatImage {
            var image:KLTFloatImage = new KLTFloatImage(bd.width, bd.height);
            for (var y:uint = 0; y < bd.height; y++) {
                for (var x:uint = 0; x < bd.width; x++) {
                    var rgb:uint = bd.getPixel(x, y);
                    image.setDataAt(x, y, (((rgb & 0xFF0000) >> 16) + ((rgb & 0x00FF00) >> 8) + (rgb & 0x0000FF)) / 3);
                }
            }
            return image;
        }

        public function toBitmapData():BitmapData {
            var bd:BitmapData = new BitmapData(nCols, nRows);
            var max:Number = Math.max.apply(Math, data), min:Number = Math.min.apply(Math, data);
            for (var y:uint = 0; y < nRows; y++) {
                for (var x:uint = 0; x < nCols; x++) {
                    var level:uint = ((getDataAt(x, y) + Math.max(0, -min)) * 256 / (max + Math.max(0, -min))) & 0xFF;
                    bd.setPixel(x, y, level | (level << 8) | (level << 16));
                }
            }
            return bd;
        }

        private function convolveImageHoriz(kernel:Array):void {
            var _data:Array = data.slice();
            var radius:uint = kernel.length / 2, len:uint = kernel.length;

            for (var y:uint = 0; y < nRows; y++) {
                for (var x:uint = 0; x < radius; x++) {
                    setDataAt(x, y, 0.0);
                }
                for (; x < nCols - radius; x++) {
                    var sum:Number = 0.0;
                    for (var k:int = len - 1; k >= 0; k--) {
                        sum += _data[y * nCols + (x - radius + k)] * kernel[k];
                    }
                    setDataAt(x, y, sum);
                }
                for (; x < nCols; x++) {
                    setDataAt(x, y, 0.0);
                }
            }
        }

        private function convolveImageVert(kernel:Array):void {
            var _data:Array = data.slice();
            var radius:uint = kernel.length / 2, len:uint = kernel.length;

            for (var x:uint = 0; x < nCols; x++) {
                for (var y:uint = 0; y < radius; y++) {
                    setDataAt(x, y, 0.0);
                }
                for (; y < nRows - radius; y++) {
                    var sum:Number = 0.0;
                    for (var k:int = len - 1; k >= 0; k--) {
                        sum += _data[(y - radius + k) * nCols + x] * kernel[k];
                    }
                    setDataAt(x, y, sum);
                }
                for (; y < nRows; y++) {
                    setDataAt(x, y, 0.0);
                }
            }
        }

        public function convolveSeparate(horizKernel:Array, vertKernel:Array):void {
            convolveImageHoriz(horizKernel);
            convolveImageVert(vertKernel);
        }

        public function computeGradients(sigma:Number):Object {
            var kernels:Object = computeKernels(sigma);
            var gaussKernel:Array      = kernels.gaussKernel;
            var gaussDerivKernel:Array = kernels.gaussDerivKernel;

            var gradX:KLTFloatImage = clone();
            gradX.convolveSeparate(gaussDerivKernel, gaussKernel);
            var gradY:KLTFloatImage = clone();
            gradY.convolveSeparate(gaussKernel, gaussDerivKernel);

            return {
                x: gradX,
                y: gradY
            };
        }

        private function computeKernels(sigma:Number):Object {
            const MAX_KERNEL_WIDTH:uint = 71;

            var gauss:Array = new Array, gaussDeriv:Array = new Array;
            var factor:Number = 0.01;
            var i:int, hw:uint;

            hw = MAX_KERNEL_WIDTH / 2;
            var maxGauss:Number = 1.0, maxGaussDeriv:Number = sigma * Math.exp(-0.5);

            for (i = -hw; i <= hw; i++) {
                var g:Number = Math.exp(-i * i / (2 * sigma * sigma));
                if (Math.abs(g / maxGauss) >= factor) {
                    gauss.push(g);
                }

                var gd:Number = -i * g;
                if (i == 0 || Math.abs(gd / maxGaussDeriv) >= factor) {
                    gaussDeriv.push(gd);
                }
            }

            var den:Number;
            den = 0.0;
            for (i = 0; i < gauss.length; i++) den += gauss[i];
            for (i = 0; i < gauss.length; i++) gauss[i] /= den;

            hw = gaussDeriv.length / 2;
            den = 0.0;
            for (i = -hw; i <= hw; i++) den -= i * gaussDeriv[i+hw];
            for (i = -hw; i <= hw; i++) gaussDeriv[hw+i] /= den;

            return {
                gaussKernel: gauss,
                gaussDerivKernel: gaussDeriv
            };
        }
    }
}
