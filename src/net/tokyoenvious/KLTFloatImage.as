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
}
