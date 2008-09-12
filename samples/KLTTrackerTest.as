import net.tokyoenvious.KLTTracker;
public function onCreationComplete():void {
    var bd:BitmapData = new BitmapData(image.width, image.height);
    bd.draw(image);
    var tracker:KLTTracker = new KLTTracker;
    var points:Array = tracker.selectGoodFeatures(bd, image.width, image.height);
    //tracker.selectGoodFeatures(bd, 100, 100);
    with (canvas.graphics) {
        beginBitmapFill(bd);
        drawRect(0, 0, bd.width, bd.height);
        endFill();
    }
    var _:int = 0;
    for each (var p:Object in points) {
        if (_++ > 1000) break;
        trace([p.x, p.y]);
        with (canvas.graphics) {
            lineStyle(1, 0xFF0000);
            drawCircle(p.x, p.y, 2);
        }
    }
}
