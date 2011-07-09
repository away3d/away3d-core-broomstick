﻿package away3d.loaders.parsers.data
{
	import flash.display.BitmapData;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	public class DefaultBitmapData {
		
		private static var _bitmapData:BitmapData;
		private static const MAX:uint = 2048;
		
		public static function get bitmapData() : BitmapData
		{
			if(!_bitmapData)
				build();
				
			return _bitmapData;
		}
		
		public static function isBitmapDataValid(bitmapData : BitmapData) : Boolean
		{
			var w:int = bitmapData.width;
			var h:int = bitmapData.height;

			if(w<2 || h<2 || w>MAX || h>MAX) return false;

			if(isPowerOfTwo(w) && isPowerOfTwo(h)) return true;

			return false;
		}

		private static function isPowerOfTwo(value:int): Boolean
		{
			return value ? ((value & -value) == value) : false;
		}

		private static function build() : void
		{
			var size:uint = 256;
			_bitmapData = new BitmapData(size,size, false, 0xFFFFFF);
			var i:uint;
			var step:int = size/8;
			var rect:Rectangle = new Rectangle(0,0,step,step);
			for(i=0;i<4;++i){
				_bitmapData.fillRect(rect, 0x000000);
				rect.x += step*2;
			}
			rect.x = 0;
			rect.width = _bitmapData.width;
			var destpt:Point = new Point(0,0);
			
			for(i=1;i<8;++i){
				destpt.x = (i%2 == 0)? 0 : step;
				destpt.y = step*i;
				_bitmapData.copyPixels(_bitmapData,rect,destpt);
			}
		}
	}
}