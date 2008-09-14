package net.tokyoenvious {
    public class KLTConvolutionKernel {
        public var width:uint;
        public var data:Array;
        public static const MAX_KERNEL_WIDTH:uint = 71;

        public function KLTConvolutionKernel() {
            data = new Array(MAX_KERNEL_WIDTH);
        }

        public static function computeKernels(sigma:Number):Object {
            var gauss:KLTConvolutionKernel      = new KLTConvolutionKernel;
            var gaussDeriv:KLTConvolutionKernel = new KLTConvolutionKernel;
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
}
