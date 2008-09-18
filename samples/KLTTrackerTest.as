import net.tokyoenvious.*;
import flash.utils.getTimer;

public function onCreationComplete():void {
    var bd1:BitmapData = new BitmapData(image.width, image.height);
    bd1.draw(image);

    var bd2:BitmapData = new BitmapData(image2.width, image2.height);
    bd2.draw(image2);

    var tracker:KLTTracker = new KLTTracker;

    var startTime:Number = getTimer();
    var features:Array = tracker.selectGoodFeatures(bd1, image.width, image.height, 30);
    trace('selectGoodFeatures: ' + (getTimer() - startTime) + ' msec');

    with (canvas.graphics) {
        beginBitmapFill(bd1);
        drawRect(0, 0, bd1.width, bd1.height);
        endFill();
        lineStyle(1, 0xFF0000);
    }
    for each (var p:KLTFeature in features) {
        canvas.graphics.drawCircle(p.x, p.y, 2);
    }

    with (canvas2.graphics) {
        beginBitmapFill(bd2);
        drawRect(0, 0, bd2.width, bd2.height);
        endFill();
        lineStyle(1, 0xFF0000);
    }
    for each (var p:KLTFeature in features) {
        canvas2.graphics.drawCircle(p.x, p.y, 2);
    }

    var startTime:Number = getTimer();
    var newFeatures:Array = tracker.trackFeatures(bd1, bd2, image.width, image.height, features);
    trace('trackFeatures: ' + (getTimer() - startTime) + ' msec');

    for (var i:int = 0; i < newFeatures.length; i++) {
        if (features[i].x != newFeatures[i].x || features[i].y != newFeatures[i].y) {
            trace('(' + features[i].x + ',' + features[i].y + ') => (' + newFeatures[i].x + ',' + newFeatures[i].y + ')');
            if (newFeatures[i].val >= 0) {
                with (canvas2.graphics) {
                    lineStyle(1, 0x0000FF);
                    moveTo(features[i].x, features[i].y);
                    lineTo(newFeatures[i].x, newFeatures[i].y);
                }
            }
        }
        with (canvas2.graphics) {
            lineStyle(1, 0x00FF00);
            drawCircle(newFeatures[i].x, newFeatures[i].y, 2);
        }
    }
}
