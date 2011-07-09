﻿package away3d.materials
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;

	import flash.display.BitmapData;
	import flash.display3D.Context3D;
	import flash.geom.ColorTransform;

	use namespace arcane;

	/**
	 * BitmapMaterial is a material that uses a BitmapData texture as the surface's diffuse colour.
	 */
	public class BitmapMaterial extends DefaultMaterialBase
	{
		private var _transparent : Boolean;

		/**
		 * Creates a new BitmapMaterial.
		 * @param bitmapData The BitmapData object to use as the texture.
		 * @param smooth Indicates whether or not the texture should use smoothing.
		 * @param repeat Indicates whether or not the texture should be tiled.
		 * @param mipmap Indicates whether or not the texture should use mipmapping.
		 */
		public function BitmapMaterial(bitmapData : BitmapData = null, smooth : Boolean = true, repeat : Boolean = false, mipmap : Boolean = true)
		{
			super();
			this.bitmapData = bitmapData;
			this.smooth = smooth;
			this.repeat = repeat;
			this.mipmap = mipmap;
		}

		public function get animateUVs() : Boolean
		{
			return _screenPass.animateUVs;
		}

		public function set animateUVs(value : Boolean) : void
		{
			_screenPass.animateUVs = value;
		}

		/**
		 * The alpha of the surface.
		 */
		public function get alpha() : Number
		{
			return _screenPass.colorTransform? _screenPass.colorTransform.alphaMultiplier : 1;
		}

		public function set alpha(value : Number) : void
		{
			if (value > 1) value = 1;
			else if (value < 0) value = 0;

			colorTransform ||= new ColorTransform();
			colorTransform.alphaMultiplier = value;
		}

//		arcane override function activatePass(index : uint, context : Context3D, contextIndex : uint, camera : Camera3D) : void
//		{
//			super.arcane::activatePass(index, context, contextIndex, camera);
//		}

		/**
		 * The BitmapData object to use as the texture.
		 */
		public function get bitmapData() : BitmapData
		{
			return _screenPass.diffuseMethod.bitmapData;
		}

		public function set bitmapData(value : BitmapData) : void
		{
			_screenPass.diffuseMethod.bitmapData = value;
		}

		/**
		 * Triggers an update of the texture, to be used when the contents of the BitmapData has changed.
		 */
		public function updateTexture() : void
		{
			_screenPass.diffuseMethod.invalidateBitmapData();
		}

		override public function get requiresBlending() : Boolean
		{
			return super.requiresBlending || _transparent;
		}

		/**
		 * Indicate whether or not the BitmapData contains transparency.
		 */
		public function get transparent() : Boolean
		{
			return _transparent;
		}

		public function set transparent(value : Boolean) : void
		{
			_transparent = value;
		}

		/**
		 * @inheritDoc
		 */
		override public function dispose(deep : Boolean) : void
		{
			if (deep)
				_screenPass.dispose(deep);
			super.dispose(deep);
		}
	}
}