import net.tokyoenvious.*;
import flash.utils.getTimer;

public function onCreationComplete():void {
    var bd:BitmapData = new BitmapData(image.width, image.height);
    bd.draw(image);

    var startTime:Number = getTimer();

    var tracker:KLTTracker = new KLTTracker;
    var features:Array = tracker.selectGoodFeatures(bd, image.width, image.height, 30);
    with (canvas.graphics) {
        beginBitmapFill(bd);
        drawRect(0, 0, bd.width, bd.height);
        endFill();
        lineStyle(1, 0xFF0000);
    }
    for each (var p:KLTFeature in features) {
        canvas.graphics.drawCircle(p.x, p.y, 2);
    }

    var py:KLTPyramid = new KLTPyramid(KLTFloatImage.fromBitmapData(bd), 2, 0.9);
    for each (var img:KLTFloatImage in py.images) {
        var bd:BitmapData = img.toBitmapData();
        canvas2.graphics.beginBitmapFill(bd);
        canvas2.graphics.drawRect(0, 0, bd.width, bd.height);
        canvas2.graphics.endFill();
    }

    trace((getTimer() - startTime) + ' msec');
}
