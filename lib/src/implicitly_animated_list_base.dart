import 'package:async/async.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'src.dart';

typedef AnimatedItemBuilder<W extends Widget, E> = W Function(
    BuildContext context, Animation<double> animation, E item, int i);

typedef RemovedItemBuilder<W extends Widget, E> = W Function(BuildContext context, Animation<double> animation, E item);

typedef UpdatedItemBuilder<W extends Widget, E> = W Function(BuildContext context, Animation<double> animation, E item);

abstract class ImplicitlyAnimatedListBase<W extends Widget, E> extends StatefulWidget {
  /// Called, as needed, to build list item widgets.
  ///
  /// List items are only built when they're scrolled into view.
  final AnimatedItemBuilder<W, E> itemBuilder;

  /// An optional builder when an item was removed from the list.
  ///
  /// If not specified, the [ImplicitlyAnimatedList] uses the [itemBuilder] with
  /// the animation reversed.
  final RemovedItemBuilder<W, E> removeItemBuilder;

  /// An optional builder when an item in the list was changed but not its position.
  ///
  /// The [UpdatedItemBuilder] animation will run from 1 to 0 and back to 1 again, while
  /// the item parameter will be the old item in the first half of the animation and the new item
  /// in the latter half of the animation. This allows you for example to fade between the old and
  /// the new item.
  ///
  /// If not specified, changes will appear instantaneously.
  final UpdatedItemBuilder<W, E> updateItemBuilder;

  /// The data that this [ImplicitlyAnimatedList] should represent.
  final List<E> items;

  /// Called by the DiffUtil to decide whether two object represent the same Item.
  /// For example, if your items have unique ids, this method should check their id equality.
  final ItemDiffUtil<E> areItemsTheSame;

  /// The duration of the animation when an item was inserted into the list.
  final Duration insertDuration;

  /// The duration of the animation when an item was removed from the list.
  final Duration removeDuration;

  /// The duration of the animation when an item changed in the list.
  final Duration updateDuration;
  const ImplicitlyAnimatedListBase({
    Key key,
    @required this.items,
    @required this.areItemsTheSame,
    @required this.itemBuilder,
    @required this.removeItemBuilder,
    @required this.updateItemBuilder,
    @required this.insertDuration,
    @required this.removeDuration,
    @required this.updateDuration,
  }) : super(key: key);
}

abstract class ImplicitlyAnimatedListBaseState<W extends Widget, B extends ImplicitlyAnimatedListBase<W, E>, E>
    extends State<B> with DiffCallback<E>, TickerProviderStateMixin {
  @protected
  GlobalKey listKey;

  @nonVirtual
  @protected
  dynamic get list => listKey.currentState;

  DiffDelegate _delegate;
  CancelableOperation _differ;

  // Animation controller for custom animation that are not supported
  // by the [AnimatedList], like updates.
  AnimationController _updateAnimController;
  AnimationController get updateAnimController => _updateAnimController;
  Animation<double> _updateAnimation;
  Animation<double> get updateAnimation => _updateAnimation;

  @protected
  List<E> dataSet;
  @protected
  List<E> newData;
  @protected
  List<E> oldData;
  @protected
  Map<E, E> changes = {};

  @nonVirtual
  @protected
  @override
  List<E> get newList => newData;

  @nonVirtual
  @protected
  @override
  List<E> get oldList => oldData;

  @nonVirtual
  @protected
  AnimatedItemBuilder<W, E> get itemBuilder => widget.itemBuilder;
  @nonVirtual
  @protected
  RemovedItemBuilder<W, E> get removeItemBuilder => widget.removeItemBuilder;
  @nonVirtual
  @protected
  UpdatedItemBuilder<W, E> get updateItemBuilder => widget.updateItemBuilder;

  @override
  void initState() {
    super.initState();
    listKey = GlobalKey();
    dataSet = List<E>.from(widget.items);
    _delegate = DiffDelegate(this);

    _updateAnimController = AnimationController(vsync: this);

    _updateAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 0.5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 0.5,
      ),
    ]).animate(_updateAnimController);

    didUpdateWidget(widget);
  }

  @override
  void didUpdateWidget(ImplicitlyAnimatedListBase oldWidget) {
    super.didUpdateWidget(oldWidget);

    newData = List<E>.from(widget.items);
    oldData = List<E>.from(dataSet);

    _updateAnimController.duration = widget.updateDuration;

    _calcDiffs();
  }

  void _calcDiffs() async {
    if (!listEquals(oldData, newData)) {
      changes.clear();

      await _differ?.cancel();
      _differ = CancelableOperation.fromFuture(
        DiffUtil.withCallback<E>(this),
      );

      final diffs = await _differ.value;
      if (diffs == null) return;
      _delegate.applyDiffs(diffs);

      _updateAnimController
        ..reset()
        ..forward();
    }
  }

  @nonVirtual
  @protected
  @override
  bool areContentsTheSame(E oldItem, E newItem) => true;

  @nonVirtual
  @protected
  @override
  bool areItemsTheSame(E oldItem, E newItem) => widget.areItemsTheSame(oldItem, newItem);

  @nonVirtual
  @protected
  @override
  void onInserted(int index, E item) {
    dataSet.insert(index, item);
    list.insertItem(index, duration: widget.insertDuration);
  }

  @nonVirtual
  @protected
  @override
  void onRemoved(int index) {
    final item = dataSet.removeAt(index);

    list.removeItem(index, (context, animation) {
      if (removeItemBuilder != null) {
        return removeItemBuilder(context, animation, item);
      }

      return itemBuilder(context, animation, item, index);
    }, duration: widget.removeDuration);
  }

  @nonVirtual
  @protected
  @override
  void onChanged(int startIndex, List<E> itemsChanged) {
    int i = 0;
    for (final item in itemsChanged) {
      final index = startIndex + i;
      changes[item] = dataSet[index];
      dataSet[index] = item;
      i++;
    }

    setState(() {});
  }

  @nonVirtual
  @protected
  Widget buildItem(BuildContext context, Animation<double> animation, E item, int index) {
    if (widget.updateItemBuilder != null && changes[item] != null) {
      return buildUpdatedItemWidget(item);
    }

    return itemBuilder(context, animation, item, index);
  }

  @protected
  Widget buildUpdatedItemWidget(E newItem) {
    final oldItem = changes[newItem];

    return AnimatedBuilder(
      animation: _updateAnimation,
      builder: (context, _) {
        final value = _updateAnimController.value;
        final item = value < 0.5 ? oldItem : newItem;

        return updateItemBuilder(context, _updateAnimation, item);
      },
    );
  }

  @override
  void dispose() {
    _updateAnimController.dispose();
    super.dispose();
  }
}
