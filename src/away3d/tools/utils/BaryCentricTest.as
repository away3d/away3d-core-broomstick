﻿package away3d.tools.utils
{
	import away3d.core.base.data.UV;
	import away3d.core.base.data.Vertex;

	import flash.geom.Vector3D;

	/**
	* Classe returns the uv's from a Vector3D on a triangle plane defined with Vertex objects. Null if outside the triangle definition
	*/
	//credits: http://www.blackpawn.com
	
	public class BaryCentricTest
	{
		private static var _bv:Vector.<Number>;
		/**
		 * Returns the uv's from a Vector3D on a triangle plane defined with Vertex objects. Null if outside the triangle definition
		 *
		 * @param	v0		Vertex. The face v0
		 * @param	v1		Vertex. The face v1
		 * @param	v2		Vertex. The face v2
		 * @param	uv0	UV. The face UV uv0
		 * @param	uv1	UV. The face UV uv1
		 * @param	uv2	UV. The face UV uv2
		 * @param	hit		Vector3D. The intersect point on triangle plane.
		 * @param	uv		[optional] UV. To prevent generation of new UV object return. Optional uv object holder can be passed.
		 */
		 
		public static  function getUVs(v0:Vertex, v1:Vertex, v2:Vertex, uv0:UV, uv1:UV, uv2:UV, hit:Vector3D, uv:UV = null):UV
		{
			if(_bv == null){
				_bv = new Vector.<Number>();
				//v0,v1,v2,dot00,dot01,dot02,dot11,dot12
				for(var i:uint=0;i<14;++i){
					_bv[i] = 0.0;
				}
			}

			var nuv:UV = uv || new UV(0.0,0.0);
			 
			_bv[0] = v2.x - v0.x;
			_bv[1] = v2.y - v0.y;
			_bv[2] = v2.z - v0.z;
			
			_bv[3] = v1.x - v0.x;
			_bv[4] = v1.y - v0.y;
			_bv[5] = v1.z - v0.z;
			
			_bv[6] = hit.x - v0.x;
			_bv[7] = hit.y - v0.y;
			_bv[8] = hit.z - v0.z;
			 
			// Compute dot products
			_bv[9] = _bv[0]*_bv[0]+_bv[1]*_bv[1]+_bv[2]*_bv[2];
			_bv[10] = _bv[0]*_bv[3]+_bv[1]*_bv[4]+_bv[2]*_bv[5];
			_bv[11] = _bv[0]*_bv[6]+_bv[1]*_bv[7]+_bv[2]*_bv[8];
			_bv[12] = _bv[3]*_bv[3]+_bv[4]*_bv[4]+_bv[5]*_bv[5];
			_bv[13] = _bv[3]*_bv[6]+_bv[4]*_bv[7]+_bv[5]*_bv[8];
			
			// Compute barycentric coordinates
			var invDenom:Number = 1 / (_bv[9] * _bv[12] - _bv[10] * _bv[10]);
			var s:Number = (_bv[12] * _bv[11] - _bv[10] * _bv[13]) * invDenom;
			var t:Number = (_bv[9] * _bv[13] - _bv[10] * _bv[11]) * invDenom;
			
			if(s > 0.0 && t > 0.0 && (s + t) < 1.0){
				nuv.u = uv0.u+s*(uv2.u-uv0.u)+t*(uv1.u-uv0.u);
				nuv.v = uv0.v+s*(uv2.v-uv0.v)+t*(uv1.v-uv0.v);
			} else {
				return null;
			}
			
			return nuv; 
		}

	}
}