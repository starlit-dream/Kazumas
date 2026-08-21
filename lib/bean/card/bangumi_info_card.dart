import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:skeletonizer/skeletonizer.dart';

// 视频卡片 - 水平布局
class BangumiInfoCardV extends StatefulWidget {
  const BangumiInfoCardV({
    super.key,
    required this.bangumiItem,
    required this.isLoading,
    required this.showRating,
    this.userRating,
    this.isLoggedIn = false,
    this.onCollectChanged,
    this.onRatingChanged,
  });

  final BangumiItem bangumiItem;
  final bool isLoading;
  final bool showRating;
  final int? userRating;
  final bool isLoggedIn;
  final Future<void> Function(int type)? onCollectChanged;
  final Future<void> Function(int rating)? onRatingChanged;

  @override
  State<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends State<BangumiInfoCardV> {
  int touchedIndex = -1;

  void _showRatingDialog(BuildContext context) {
    double currentRating = (widget.userRating ?? 0).toDouble();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('修改评分'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '为《${widget.bangumiItem.nameCn.isNotEmpty ? widget.bangumiItem.nameCn : widget.bangumiItem.name}》评分',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Text(
                      '${currentRating.toInt()}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RatingBar.builder(
                      initialRating: currentRating / 2,
                      minRating: 0.5,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 40,
                      itemBuilder: (context, _) => Icon(
                        Icons.star_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onRatingUpdate: (rating) {
                        setState(() {
                          currentRating = rating * 2;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (widget.onRatingChanged != null) {
                widget.onRatingChanged!(currentRating.toInt());
              }
              Navigator.of(context).pop();
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget get voteBarChart {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '  评分透视:',
          ),
          SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 2,
            child: BarChart(
              duration: Duration(milliseconds: 80),
              BarChartData(
                // alignment: BarChartAlignment.spaceEvenly,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      var percentage =
                          widget.bangumiItem.votesCount[groupIndex] /
                              widget.bangumiItem.votes *
                              100;
                      return BarTooltipItem(
                        '${percentage.toStringAsFixed(2)}% (${widget.bangumiItem.votesCount[groupIndex]}人)',
                        TextStyle(
                            color:
                                Theme.of(context).colorScheme.onInverseSurface),
                      );
                    },
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(
                  10,
                  (i) => BarChartGroupData(
                    x: i + 1,
                    barRods: [
                      BarChartRodData(
                        toY: widget.bangumiItem.votesCount[i].toDouble(),
                        color: touchedIndex == i
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                        width: 20,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(5)),
                      )
                    ],
                    // showingTooltipIndicators: [0],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: 10,
                        child: Text(value.toInt().toString()),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      constraints: BoxConstraints(maxWidth: 950),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.bangumiItem.nameCn == ''
                ? widget.bangumiItem.name
                : (widget.bangumiItem.nameCn),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 0.65,
                    child: LayoutBuilder(builder: (context, boxConstraints) {
                      final double maxWidth = boxConstraints.maxWidth;
                      final double maxHeight = boxConstraints.maxHeight;
                      return Hero(
                        transitionOnUserGestures: true,
                        flightShuttleBuilder:
                            NetworkImgLayer.heroFlightShuttleBuilder,
                        tag: widget.bangumiItem.id,
                        child: NetworkImgLayer(
                          src: widget.bangumiItem.images['large'] ?? '',
                          width: maxWidth,
                          height: maxHeight,
                          fadeInDuration: const Duration(milliseconds: 0),
                          fadeOutDuration: const Duration(milliseconds: 0),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(width: 16),
                Flexible(
                  child: Skeletonizer(
                    enabled: widget.isLoading,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '放送开始:',
                            ),
                            Text(
                              widget.bangumiItem.airDate == ''
                                  ? '2000-11-11' // Skeleton Loader 占位符
                                  : widget.bangumiItem.airDate,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              widget.showRating
                                  ? '${widget.bangumiItem.votes} 人评分:'
                                  : '*** 人评分:',
                            ),
                            if (widget.isLoading)
                              // Skeleton Loader 占位符
                              Text(
                                '10.0 ********',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            if (!widget.isLoading)
                              Row(
                                children: [
                                  Text(
                                    widget.showRating
                                        ? '${widget.bangumiItem.ratingScore}'
                                        : '***',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  RatingBarIndicator(
                                    itemCount: 5,
                                    rating: widget.showRating
                                        ? widget.bangumiItem.ratingScore
                                                .toDouble() /
                                            2
                                        : 0,
                                    itemBuilder: (context, index) => Icon(
                                      Icons.star_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    itemSize: 20.0,
                                  ),
                                ],
                              ),
                            SizedBox(height: 8),
                            Text(
                              'Bangumi Ranked:',
                            ),
                            Text(
                              widget.showRating
                                  ? '#${widget.bangumiItem.rank}'
                                  : '***',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (widget.isLoggedIn) ...[
                              SizedBox(height: 8),
                              if (widget.userRating != null && widget.userRating! > 0) ...[
                                Text(
                                  '我的评分:',
                                ),
                                GestureDetector(
                                  onTap: () => _showRatingDialog(context),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${widget.userRating}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      RatingBarIndicator(
                                        itemCount: 5,
                                        rating: widget.userRating!.toDouble() / 2,
                                        itemBuilder: (context, index) => Icon(
                                          Icons.star_rounded,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                        itemSize: 20.0,
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.edit_rounded,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                TextButton.icon(
                                  onPressed: () => _showRatingDialog(context),
                                  icon: Icon(Icons.star_border_rounded, size: 18),
                                  label: Text('添加评分'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size(0, 32),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                        SizedBox(
                          width: 120,
                          height: 40,
                           child: CollectButton.extend(
                             bangumiItem: widget.bangumiItem,
                             onCollectChanged: widget.onCollectChanged,
                           ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.showRating &&
                    MediaQuery.sizeOf(context).width >=
                        LayoutBreakpoint.compact['width']! &&
                    !widget.isLoading)
                  voteBarChart,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
