/// * 操作状态
/// * [editing] 正在编辑
/// * [moving] 正在移动
/// * [scaling] 正在缩放
/// * [rotating] 正在旋转
/// * [idle] 常规状态
/// * [complete] 编辑完成
enum OperationState {
  /// 正在编辑
  editing,

  /// 正在移动
  moving,

  /// 正在缩放
  scaling,

  /// 正在旋转
  rotating,

  /// 常规状态
  idle,

  /// 编辑完成
  complete,
}
