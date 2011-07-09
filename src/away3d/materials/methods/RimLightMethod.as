/**
 * Author: David Lenaerts
 */
package away3d.materials.methods
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.materials.utils.ShaderRegisterCache;
	import away3d.materials.utils.ShaderRegisterElement;

	import flash.display3D.Context3DProgramType;

	use namespace arcane;

	public class RimLightMethod extends ShadingMethodBase
	{
		private var _color : uint;
		private var _data : Vector.<Number>;
		private var _dataIndex : int;

		public function RimLightMethod(color : uint = 0xffffff, strength : Number = .4, power : Number = 2)
		{
			super(true, true, false);
			_data = new Vector.<Number>(8, true);
			_data[3] = 1;
			_data[4] = strength;
			_data[5] = power;
			this.color = color;
		}

		public function get color() : uint
		{
			return _color;
		}

		public function set color(value : uint) : void
		{
			_color = value;
			_data[0] = ((value >> 16) & 0xff)/0xff;
			_data[1] = ((value >> 8) & 0xff)/0xff;
			_data[2] = (value & 0xff)/0xff;
		}

		public function get strength() : Number
		{
			return _data[4];
		}

		public function set strength(value : Number) : void
		{
			_data[4] = value;
		}

		public function get power() : Number
		{
			return _data[5];
		}

		public function set power(value : Number) : void
		{
			_data[5] = value;
		}

		arcane override function activate(stage3DProxy : Stage3DProxy) : void
		{
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, _dataIndex, _data, 2);
		}

		arcane override function getFragmentPostLightingCode(regCache : ShaderRegisterCache, targetReg : ShaderRegisterElement) : String
		{
			var dataRegister : ShaderRegisterElement = regCache.getFreeFragmentConstant();
			var dataRegister2 : ShaderRegisterElement = regCache.getFreeFragmentConstant();
			var temp : ShaderRegisterElement = regCache.getFreeFragmentVectorTemp();
			var code : String = "";
			_dataIndex = dataRegister.index;

			code += "dp3 " + temp + ".x, " + _viewDirFragmentReg + ".xyz, " + _normalFragmentReg + ".xyz	\n" +
					"sat " + temp + ".x, " + temp + ".x														\n" +
					"sub " + temp + ".x, " + dataRegister + ".w, " + temp + ".x								\n" +
					"pow " + temp + ".x, " + temp + ".x, " + dataRegister2 + ".y							\n" +
					"mul " + temp + ".x, " + temp + ".x, " + dataRegister2 + ".x							\n" +
					"sub " + temp + ".x, " + dataRegister + ".w, " + temp + ".x								\n" +
					"mul " + targetReg + ".xyz, " + targetReg + ".xyz, " + temp + ".x						\n" +
					"sub " + temp + ".x, " + dataRegister + ".w, " + temp + ".x								\n" +
					"mul " + temp + ".xyz, " + temp + ".x, " + dataRegister + ".xyz							\n" +
					"add " + targetReg + ".xyz, " + targetReg+".xyz, " + temp + ".xyz						\n";

			return code;
		}
	}
}
