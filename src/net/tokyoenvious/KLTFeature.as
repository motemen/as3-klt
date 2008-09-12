package net.tokyoenvious {
    public class KLTFeature {
        public static const KLT_NOT_FOUND:int = -1;

        public var x:Number, y:Number;
        public var val:int;

        /* for affine mapping */
        public var affImg:KLTFloatImage;
        public var affImgGradX:KLTFloatImage;
        public var affImgGradY:KLTFloatImage;

        public var affX:Number;
        public var affY:Number;
        public var affAxx:Number;
        public var affAyx:Number;
        public var affAxy:Number;
        public var affAyy:Number;

        public function KLTFeature(_x:Number, _y:Number, _val:Number) {
            x = _x;
            y = _y;
            val = _val;
            affX = -1.0;
            affY = -1.0;
            affAxx = 1.0;
            affAyx = 0.0;
            affAxy = 0.0;
            affAyy = 1.0;
        }

        public function toString():String {
            return '[KLTFeature (' + x + ',' + y + ')]';
        }
    }
}
