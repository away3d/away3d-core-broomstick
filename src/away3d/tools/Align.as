﻿package away3d.tools
{
	import away3d.arcane;

	use namespace arcane;
	
	/**
	* Class Aligns an arrays of Object3Ds, Vector3D's or Vertexes compaired to each other.<code>Align</code>
	*/
	public class Align {
		
		private static var _axis:String;
		private static var _condition:String;
		
		/**
		* Applies to array elements the alignment according to axis, x, y or z and a condition.
		* each element must have public x,y and z  properties
		* String condition:
		* "+" align to highest value on a given axis
		* "-" align to lowest value on a given axis
		* "" align to a given axis on 0; This is the default.
		* "av" align to average of all values on a given axis
		*
		* @param	 aObjs		Array. An array with elements with x,y and z public properties such as Mesh, Object3D, ObjectContainer3D,Vector3D or Vertex
		* @param	 axis			String. Represent the axis to align on.
		* @param	 condition	[optional]. String. Can be '+", "-", "av" or "", Default is "", aligns to given axis at 0.
		*/		
		public static function align(aObjs:Array, axis:String, condition:String = ""):void
		{
			checkAxis(axis);
			checkCondition(condition);
			var base:Number;			
			
			switch(_condition){
				case "+":
					base = getMax(aObjs, _axis);
					break;
				
				case "-":
					base = getMin(aObjs, _axis);
					break;
				
				case "av":
					base = getAverage(aObjs, _axis);
					break;
				
				case "":
					base = 0;
			}
			
			for(var i:uint = 0;i<aObjs.length;++i){
				aObjs[i][_axis] = base;
			}
		}
		
		/**
		* Applies to array elements a distributed alignment according to axis, x,y or z.
		* each element must have public x,y and z  properties
		* @param	 aObjs		Array. An array with elements with x,y and z public properties such as Mesh, Object3D, ObjectContainer3D,Vector3D or Vertex
		* @param	 axis			String. Represent the axis to align on.
		*/		
		public static function distribute(aObjs:Array, axis:String):void
		{
			checkAxis(axis);

			var max:Number = getMax(aObjs, _axis);
			var min:Number = getMin(aObjs, _axis);
			var unit:Number = (max - min) / aObjs.length;
			aObjs.sortOn(axis, 16);
			
			var step:Number = 0;
			for(var i:uint = 0;i<aObjs.length;++i){
				aObjs[i][_axis] = min+step;
				step+=unit;
			}
		}
		
		private static function checkAxis(axis:String):void
		{
			axis = axis.substring(0, 1).toLowerCase();
			if(axis == "x" || axis == "y" || axis == "z"){
				_axis  = axis;
				return;
			}
			
			throw new Error("Invalid axis: string value must be 'x', 'y' or 'z'");
		}
		
		private static function checkCondition(condition:String):void
		{
			condition = condition.toLowerCase();
			var aConds:Array = ["+", "-", "", "av"];
			for(var i:uint = 0;i<aConds.length;++i){
				if(aConds[i] == condition){
					_condition  = condition;
					return;
				}
			}
			
			throw new Error("Invalid condition: possible string value are '+', '-', 'av' or '' ");
		}
		
		private static function getMin(a:Array, prop:String):Number
		{
			var min:Number = Infinity;
			for(var i:uint = 0;i<a.length;++i){
				min = Math.min(a[i][prop], min);
			}
			return min;
		}
		
		private static function getMax(a:Array, prop:String):Number
		{
			var max:Number = -Infinity;
			for(var i:uint = 0;i<a.length;++i){
				max = Math.max(a[i][prop], max);
			}
			return max;
		}
		
		private static function getAverage(a:Array, prop:String):Number
		{
			var av:Number = 0;
			var loop:int = a.length;
			for(var i:uint = 0;i<loop;++i){
				av += a[i][prop];
			}
			return av/loop;
		}
		 
	}
}