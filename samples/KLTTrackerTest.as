import net.tokyoenvious.KLTTracker;
import net.tokyoenvious.KLTFeature;

public function onCreationComplete():void {
    var bd:BitmapData = new BitmapData(image.width, image.height);
    bd.draw(image);
    var tracker:KLTTracker = new KLTTracker;
    var features:Array = tracker.selectGoodFeatures(bd, image.width, image.height, 20);
    //tracker.selectGoodFeatures(bd, 100, 100);
    with (canvas.graphics) {
        beginBitmapFill(bd);
        drawRect(0, 0, bd.width, bd.height);
        endFill();
        lineStyle(1, 0xFF0000);
    }
    trace(features);
    for each (var p:KLTFeature in features) {
        trace([p.x, p.y]);
        canvas.graphics.drawCircle(p.x, p.y, 2);
    }
}
