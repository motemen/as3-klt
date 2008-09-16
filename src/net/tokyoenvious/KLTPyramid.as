package net.tokyoenvious {
    public class KLTPyramid {
        public var nLevels:uint;
        public var images:Array;

        public function KLTPyramid(image:KLTFloatImage, _nLevels:uint, sigmaFact:Number) {
            nLevels = _nLevels;
            images = new Array;

            images.push(image.clone());

            var nCols:uint = image.nCols / 4, nRows:uint = image.nRows / 4;
            var currImg:KLTFloatImage = images[0];
            for (var i:uint = 1; i < nLevels; i++) {
                var img:KLTFloatImage = new KLTFloatImage(nCols, nRows);
                for (var y:uint = 0; y < nRows; y++) {
                    for (var x:uint = 0; x < nCols; x++) {
                        img.setDataAt(x, y, currImg.getDataAt(4 * x + 2, 4 * y + 2)); // XXX 4 == subsampling
                    }
                }
                images.push(img);
                currImg = img.clone();
                nCols /= 4, nRows /= 4;
                //currImg.smooth(subsampling * sigmaFact);
            }
        }
    }
}
