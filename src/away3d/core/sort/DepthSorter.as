package away3d.core.sort
{
	import away3d.core.base.IRenderable;
	import away3d.core.traverse.EntityCollector;

	/**
	 * RenderableSorter sorts the potentially visible IRenderable objects collected by EntityCollector for optimal
	 * rendering performance. Objects are sorted first by material, then by distance to the camera. Opaque objects
	 * are sorted front to back, while objects that require blending are sorted back to front, to ensure correct
	 * blending.
	 */
	public class DepthSorter extends EntitySorterBase
	{
		/**
		 * Creates a RenderableSorter objects
		 */
		public function DepthSorter()
		{
		}

		/**
		 * @inheritDoc
		 */
		override public function sort(collector : EntityCollector) : void
		{
			collector.opaqueRenderables = collector.opaqueRenderables.sort(opaqueSortFunction);
			collector.blendedRenderables = collector.blendedRenderables.sort(opaqueSortFunction);
		}

		/**
		 * Sorts per material, then per zIndex, front to back, for opaques
		 */
		private function opaqueSortFunction(a : IRenderable, b : IRenderable) : int
		{
			var za : Number = a.zIndex;
			var zb : Number = b.zIndex;
			if (za == zb) return 0;
			else if (za > zb) return 1;
			else return -1;
		}
	}
}