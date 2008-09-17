package net.tokyoenvious {
    public class KLTPyramid {
        public var nLevels:uint;
        public var images:Array;

        public function KLTPyramid(image:KLTFloatImage, _nLevels:uint, sigmaFact:Number, subsampling:uint) {
            nLevels = _nLevels;
            images = new Array;

            images.push(image.clone());

            var nCols:uint = image.nCols / subsampling, nRows:uint = image.nRows / subsampling;
            var currImg:KLTFloatImage = images[0];
            for (var i:uint = 1; i < nLevels; i++) {
                var img:KLTFloatImage = new KLTFloatImage(nCols, nRows);
                for (var y:uint = 0; y < nRows; y++) {
                    for (var x:uint = 0; x < nCols; x++) {
                        img.setDataAt(x, y, currImg.getDataAt(subsampling * x + 2, subsampling * y + 2)); // XXX 4 == subsampling
                    }
                }
                images.push(img);
                currImg = img.clone();
                nCols /= subsampling, nRows /= subsampling;
                //currImg.smooth(subsampling * sigmaFact);
            }
        }
    }
}
