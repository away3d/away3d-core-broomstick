package away3d.containers
{
	import away3d.arcane;
	import away3d.core.base.*;
	import away3d.core.partition.Partition3D;
	import away3d.events.Scene3DEvent;
	import away3d.library.assets.AssetType;
	import away3d.library.assets.IAsset;

	import flash.events.Event;
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;

	use namespace arcane;
	
	/**
	 * ObjectContainer3D is the most basic scene graph node. It can contain other ObjectContainer3Ds.
	 *
	 * ObjectContainer3D can have its own scene partition assigned. However, when assigned to a different scene,
	 * it will loose any partition information, since partitions are tied to a scene.
	 *
	 * TODO: polycount updates
	 * TODO: all the event-based stuff is not done (onDimensionsUpdate etc) Trying to avoid bubbling here :s
	 * TODO: names not implemented yet (will be related too closely to a Library)
	 * TODO: pivot stuff --> pass pivot point to appendRotation
	 *
	 */
	public class ObjectContainer3D extends Object3D implements IAsset
	{
		private var _children : Vector.<ObjectContainer3D>;
		
		protected var _scene : Scene3D;
		private var _oldScene : Scene3D;
		protected var _parent : ObjectContainer3D;
		
		protected var _sceneTransform : Matrix3D = new Matrix3D();
		protected var _sceneTransformDirty : Boolean = true;
		private var _inverseSceneTransform : Matrix3D = new Matrix3D();
		private var _inverseSceneTransformDirty : Boolean = true;
		private var _scenePosition : Vector3D = new Vector3D();
		private var _scenePositionDirty : Boolean = true;
		
		// _explicitPartition is what the user explicitly set as the partition
		// implicitPartition is what is inherited from the parents if it doesn't have its own explicitPartition
		// this allows not having to traverse the scene graph to figure out what partition is set
		protected var _explicitPartition : Partition3D;
		protected var _implicitPartition : Partition3D;

		private var _explicitVisibility : Boolean = true;

		// visibility passed on from parents
		private var _implicitVisibility : Boolean = true;

		/**
		 * Creates a new ObjectContainer3D object.
		 */
		public function ObjectContainer3D()
		{
			super();
			_children = new Vector.<ObjectContainer3D>();
		}

		public function get visible() : Boolean
		{
			return _explicitVisibility;
		}

		public function set visible(value : Boolean) : void
		{
			var len : uint = _children.length;

			_explicitVisibility = value;

			for (var i : uint = 0; i < len; ++i) {
				_children[i]._implicitVisibility = _explicitVisibility && _implicitVisibility;
			}
		}

		arcane function get isVisible() : Boolean
		{
			return _implicitVisibility && _explicitVisibility;
		}

		public function get assetType() : String
		{
			return AssetType.CONTAINER;
		}
		
		/**
		 * The global position of the ObjectContainer3D in the scene.
		 */
		public function get scenePosition() : Vector3D
		{
			if (_scenePositionDirty) {
				sceneTransform.copyRowTo(3, _scenePosition);
				_scenePositionDirty = false;
			}
			return _scenePosition;
		}
		
		/**
		 * The minimum extremum of the object along the X-axis.
		 */
		public function get minX() : Number
		{
			var i : uint;
			var len : uint = _children.length;
			var min : Number = Number.POSITIVE_INFINITY;
			var m : Number;
			while (i < len) {
				m = _children[i++].minX;
				if (m < min) min = m;
			}
			return min;
		}
		
		/**
		 * The minimum extremum of the object along the Y-axis.
		 */
		public function get minY() : Number
		{
			var i : uint;
			var len : uint = _children.length;
			var min : Number = Number.POSITIVE_INFINITY;
			var m : Number;
			while (i < len) {
				m = _children[i++].minY;
				if (m < min) min = m;
			}
			return min;
		}
		
		/**
		 * The minimum extremum of the object along the Z-axis.
		 */
		public function get minZ() : Number
		{
			var i : uint;
			var len : uint = _children.length;
			var min : Number = Number.POSITIVE_INFINITY;
			var m : Number;
			while (i < len) {
				m = _children[i++].minZ;
				if (m < min) min = m;
			}
			return min;
		}
		
		/**
		 * The maximum extremum of the object along the X-axis.
		 */
		public function get maxX() : Number
		{
			// todo: this isn't right, doesn't take into account transforms
			var i : uint;
			var len : uint = _children.length;
			var max : Number = Number.NEGATIVE_INFINITY;
			var m : Number;
			while (i < len) {
				m = _children[i++].maxX;
				if (m > max) max = m;
			}
			return max;
		}
		
		/**
		 * The maximum extremum of the object along the Y-axis.
		 */
		public function get maxY() : Number
		{
			var i : uint;
			var len : uint = _children.length;
			var max : Number = Number.NEGATIVE_INFINITY;
			var m : Number;
			while (i < len) {
				m = _children[i++].maxY;
				if (m > max) max = m;
			}
			return max;
		}
		
		/**
		 * The maximum extremum of the object along the Z-axis.
		 */
		public function get maxZ() : Number
		{
			var i : uint;
			var len : uint = _children.length;
			var max : Number = Number.NEGATIVE_INFINITY;
			var m : Number;
			while (i < len) {
				m = _children[i++].maxZ;
				if (m > max) max = m;
			}
			return max;
		}
		
		/**
		 * The space partition to be used by the object container and all its recursive children, unless it has its own
		 * space partition assigned.
		 */
		public function get partition() : Partition3D
		{
			return _explicitPartition;
		}
		
		public function set partition(value : Partition3D) : void
		{
			_explicitPartition = value;
			implicitPartition = value 	? value :
				_parent	? parent.implicitPartition
				: null;
		}
		
		/**
		 * The space partition used for this object, possibly inherited from its parent.
		 */
		arcane function get implicitPartition() : Partition3D
		{
			return _implicitPartition;
		}
		
		arcane function set implicitPartition(value : Partition3D) : void
		{
			if (value == _implicitPartition) return;
			
			var i : uint;
			var len : uint = _children.length;
			var child : ObjectContainer3D;
			
			_implicitPartition = value;
			
			while (i < len) {
				child = _children[i++];
				// assign implicit partition if no explicit one is given
				if (!child._explicitPartition) child.implicitPartition = value;
			}
		}
		
		/**
		 * The local transformation matrix that transforms to the parent object's space.
		 * @param value
		 */
		override public function set transform(value : Matrix3D) : void
		{
			super.transform = value;
			invalidateSceneTransform();
		}
		
		/**
		 * The transformation matrix that transforms from model to world space.
		 */
		public function get sceneTransform() : Matrix3D
		{
			if (_sceneTransformDirty) updateSceneTransform();
			return _sceneTransform;
		}
		
		/**
		 * The inverse scene transform object that transforms from world to model space.
		 */
		public function get inverseSceneTransform() : Matrix3D
		{
			if (_inverseSceneTransformDirty) {
				_inverseSceneTransform.copyFrom(sceneTransform);
				_inverseSceneTransform.invert();
				_inverseSceneTransformDirty = false;
			}
			return _inverseSceneTransform;
		}
		
		/**
		 * The parent ObjectContainer3D to which this object's transformation is relative.
		 */
		public function get parent() : ObjectContainer3D
		{
			return _parent;
		}
		
		arcane function setParent(value : ObjectContainer3D) : void
		{
			_parent = value;
			
			if (value == null) {
				scene = null;
				return;
			}
			
			invalidateSceneTransform();
		}
		
		/**
		 * Adds a child ObjectContainer3D to the current object. The child's transformation will become relative to the
		 * current object's transformation.
		 * @param child The object to be added as a child.
		 * @return A reference to the added child object.
		 */
		public function addChild(child : ObjectContainer3D) : ObjectContainer3D
		{
			if (child == null)
				throw new Error("Parameter child cannot be null.");
			
			if (!child._explicitPartition) child.implicitPartition = _implicitPartition;
			
			child._parent = this;
			child.scene = _scene;
			child.invalidateSceneTransform();
			
			
			_children.push(child);
			return child;
		}
		
		/**
		 * Adds an array of 3d objects to the scene as children of the container
		 *
		 * @param	...childarray		An array of 3d objects to be added
		 */
		public function addChildren(...childarray):void
		{
			for each (var child:ObjectContainer3D in childarray)
			addChild(child);
		}
		
		/**
		 * Removes a 3d object from the child array of the container
		 *
		 * @param	child	The 3d object to be removed
		 * @throws	Error	ObjectContainer3D.removeChild(null)
		 */
		public function removeChild(child:ObjectContainer3D):void
		{
			if (child == null)
				throw new Error("Parameter child cannot be null");
			
			var childIndex : int = _children.indexOf(child);
			
			if (childIndex == -1) throw new Error("Parameter is not a child of the caller");
			
			// index is important because getChildAt needs to be regular.
			_children.splice(childIndex, 1);
			
			// this needs to be nullified before the callbacks!
			child.setParent(null);
			if (!child._explicitPartition) child.implicitPartition = null;
		}
		
		/**
		 * Retrieves the child object at the given index.
		 * @param index The index of the object to be retrieved.
		 * @return The child object at the given index.
		 */
		public function getChildAt(index : uint) : ObjectContainer3D
		{
			return _children[index];
		}
		
		/**
		 * The amount of child objects of the ObjectContainer3D.
		 */
		public function get numChildren() : uint
		{
			return _children.length;
		}
		
		/**
		 * @inheritDoc
		 */
		override public function lookAt(target:Vector3D, upAxis:Vector3D = null):void
		{
			super.lookAt(target, upAxis);
			invalidateSceneTransform();
		}
		
		override public function translateLocal(axis : Vector3D, distance : Number) : void
		{
			super.translateLocal(axis, distance);
			invalidateSceneTransform();
		}
		
		/**
		 * @inheritDoc
		 */
		override public function dispose(deep : Boolean) : void
		{
			if (parent) parent.removeChild(this);
			
			if (deep)
				for (var i : uint = 0; i < _children.length; ++i)
					_children[i].dispose(true);
		}
		
		/**
		 * A reference to the Scene3D object to which this object belongs.
		 */
		arcane function get scene() : Scene3D
		{
			return _scene;
		}
		
		arcane function set scene(value : Scene3D) : void
		{
			var i : uint;
			var len : uint = _children.length;
			while (i < len) _children[i++].scene = value;
			
			if (_scene == value) return;
			// test to see if we're switching roots while we're already using a scene partition
			if (value == null)
				_oldScene = _scene;
			if (_explicitPartition && _oldScene && _oldScene != _scene)
				partition = null;
			if (value) _oldScene = null;
			// end of stupid partition test code
			
			_scene = value;
			
			if(_scene) {
				_scene.dispatchEvent(new Scene3DEvent(Scene3DEvent.ADDED_TO_SCENE, this));
			} else if(_oldScene) {
				_oldScene.dispatchEvent(new Scene3DEvent(Scene3DEvent.REMOVED_FROM_SCENE, this));
			}
		}
		
		/**
		 * @inheritDoc
		 */
		override protected function invalidateTransform() : void
		{
			super.invalidateTransform();
			invalidateSceneTransform();
		}
		
		/**
		 * Invalidates the scene transformation matrix, causing it to be updated the next time it's requested.
		 */
		protected function invalidateSceneTransform() : void
		{
			_scenePositionDirty = true;
			_inverseSceneTransformDirty = true;
			
			if (_sceneTransformDirty) return;
			
			_sceneTransformDirty = true;
			
			var i : uint;
			var len : uint = _children.length;
			while (i < len) _children[i++].invalidateSceneTransform();
		}
		
		/**
		 * Updates the scene transformation matrix.
		 */
		protected function updateSceneTransform():void
		{
			if (_parent) {
				_sceneTransform.copyFrom(_parent.sceneTransform);
				_sceneTransform.prepend(transform);
			}
			else {
				_sceneTransform.copyFrom(transform);
			}
			
			_sceneTransformDirty = false;
		}


		/**
		 * @inheritDoc
		 */
		// maybe not the best way to fake bubbling?
		override public function dispatchEvent(event : Event) : Boolean
		{
			var ret : Boolean =  super.dispatchEvent(event);

			if (event.bubbles) {
				if (_parent)
					_parent.dispatchEvent(event);
				// if it's scene root
				else if (_scene)
					_scene.dispatchEvent(event);
			}

			return ret;
		}
	}
}