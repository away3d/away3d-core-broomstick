﻿package away3d.primitives
{
	import away3d.entities.*;

	import flash.geom.Vector3D;

	/**
	* Class WireframeGrid generates a grid of lines on a given plane<code>WireframeGrid</code>
	* @param	subDivision		[optional] uint . Default is 10;
	* @param	gridSize				[optional] uint . Default is 100;
	* @param	color					[optional] uint . Default is 0xFFFFFF;
	* @param	thickness			[optional] Number . Default is 1;
	* @param	plane					[optional] String . Default is PLANE_XZ;
	* @param	worldPlanes		[optional] Boolean . Default is false.
	* If true, class displays the 3 world planes, at 0,0,0. with subDivision, thickness and gridSize. Overrides color and plane settings.
	*/
		
	public class WireframeGrid extends SegmentSet
	{
		public static const PLANE_ZY:String = "zy";
		public static const PLANE_XY:String = "xy";
		public static const PLANE_XZ:String = "xz";
		
		public function WireframeGrid(subDivision:uint = 10, gridSize:uint = 100, thickness:Number = 1, color:uint = 0xFFFFFF,  plane:String = "xz", worldPlanes:Boolean = false ) {
			super();
			
			if(subDivision == 0) subDivision = 1;
			if(thickness <= 0) thickness = 1;
			if(gridSize ==  0) gridSize = 1;
			 
			if(worldPlanes){
				build(subDivision, gridSize, 0x0000FF, thickness, PLANE_XY);
				build(subDivision, gridSize, 0xFF0000, thickness, PLANE_ZY);
				build(subDivision, gridSize, 0x00FF00, thickness, PLANE_XZ);
			} else{
				build(subDivision, gridSize, color, thickness, plane);
			}
		}
		
		private function build(subDivision:uint, gridSize:uint, color:uint, thickness:Number, plane:String):void
		{
			var bound:Number = gridSize *.5;
			var step:Number = gridSize/subDivision;
			var v0 : Vector3D = new Vector3D(0, 0, 0) ;
			var v1 : Vector3D = new Vector3D(0, 0, 0) ;
			var inc:Number = -bound;
			
			while(inc<=bound){
				 
				switch(plane){
					case PLANE_ZY:
						v0.x = 0;
						v0.y = inc;
						v0.z = bound;
						v1.x = 0;
						v1.y = inc;
						v1.z = -bound;
						addSegment( new LineSegment(v0, v1, color, color, thickness));
						
						v0.z = inc;
						v0.x = 0;
						v0.y = bound;
						v1.x = 0;
						v1.y = -bound;
						v1.z = inc;
						addSegment(new LineSegment(v0, v1, color, color, thickness ));
						break;
						
					case PLANE_XY:
						v0.x = bound;
						v0.y = inc;
						v0.z = 0;
						v1.x = -bound;
						v1.y = inc;
						v1.z = 0;
						addSegment( new LineSegment(v0, v1, color, color, thickness));
						v0.x = inc;
						v0.y = bound;
						v0.z = 0;
						v1.x = inc;
						v1.y = -bound;
						v1.z = 0;
						addSegment(new LineSegment(v0, v1, color, color, thickness ));
						break;
						
					default:
						v0.x = bound;
						v0.y = 0;
						v0.z = inc;
						v1.x = -bound;
						v1.y = 0;
						v1.z = inc;
						addSegment( new LineSegment(v0, v1, color, color, thickness));
						
						v0.x = inc;
						v0.y = 0;
						v0.z = bound;
						v1.x = inc;
						v1.y = 0;
						v1.z = -bound;
						addSegment(new LineSegment(v0, v1, color, color, thickness ));
				}
				
				inc += step;
			}
		}
		
	}
}
