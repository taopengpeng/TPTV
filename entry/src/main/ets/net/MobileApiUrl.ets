/**
 * 服务器接口常量（对应旧版 com.licq.tv.net.MobileApiUrl）
 *
 * 注：以下接口已于 2026-09 实测全部下线（api.apiopen.top 各路径统一返回 HTML 官网页面），
 * 常量与注释清单仅作接口定义留存；接入新后端时替换 Constants.BASEURL 并按需调整路径。
 */
export class MobileApiUrl {
  // 登录接口（POST）
  static readonly HEALTHCARE_LOGIN: string = 'appserver/phone/member4_login.xhtml';
  // 获取消息通知（GET）
  static readonly HEALTHCARE_GETNOTICE: string = 'appserver/phone/member4_notice.xhtml';
  // 新实时段子（GET，参数 page / count / type=video）
  static readonly APIOPEN_GETJOKE: string = 'getJoke';
}

/*
 * ===== 旧版 MobileApiUrl.java 中注释的接口地址清单（原样留存，均已下线） =====
 *
 * 通过Id查段子       https://api.apiopen.top/getSingleJoke?sid=28654780
 * 快递查询           https://api.apiopen.top/EmailSearch?number=1012002
 * 随机单句诗词推荐    https://api.apiopen.top/singlePoetry
 * 随机一首诗词推荐    https://api.apiopen.top/recommendPoetry
 * 搜索古诗词         https://api.apiopen.top/searchPoetry?name=古风二首 二
 * 搜索古诗词作者      https://api.apiopen.top/searchAuthors?name=李白
 * 模糊搜索古诗词      https://api.apiopen.top/likePoetry?name=李白
 * 获取宋朝古诗词      https://api.apiopen.top/getSongPoetry?page=1&count=20
 * 获取唐朝古诗词      https://api.apiopen.top/getTangPoetry?page=1&count=20
 * 音乐搜索接口       https://api.apiopen.top/searchMusic?name=不要说话
 * 音乐电台接口       https://api.apiopen.top/musicBroadcasting
 * 音乐电台详情       https://api.apiopen.top/musicBroadcastingDetails?channelname=public_tuijian_spring
 * 音乐详情接口       https://api.apiopen.top/musicDetails?id=604392760
 * 音乐排行榜         https://api.apiopen.top/musicRankings
 * 音乐排行榜详情     https://api.apiopen.top/musicRankingsDetails?type=1
 * 每日视频推荐       https://api.apiopen.top/todayVideo
 * 视频大纲获取       https://api.apiopen.top/videoHomeTab
 * 视频分类推荐       https://api.apiopen.top/videoCategory
 * 视频分类推荐详情    https://api.apiopen.top/videoCategoryDetails?id=14
 * 根据ID推荐视频     https://api.apiopen.top/videoRecommend?id=127398
 * 新闻接口           https://www.apiopen.top/journalismApi
 * 随机推荐热门段子    https://www.apiopen.top/satinApi?type=1&page=1
 * 热门段子神评版本    https://www.apiopen.top/satinGodApi?type=1&page=1
 * 神评版本评论列表    https://www.apiopen.top/satinCommentApi?id=27610708&page=1
 * 热门小说推荐列表    https://www.apiopen.top/novelApi
 * 小说搜索接口       https://www.apiopen.top/novelSearchApi?name=盗墓笔记
 * 小说详情接口       https://www.apiopen.top/novelInfoApi?name=盗墓笔记
 * 天气获取接口       https://www.apiopen.top/weatherApi?city=成都
 * 美图获取接口       https://www.apiopen.top/meituApi?page=1
 * 个性网名获取       https://www.apiopen.top/femaleNameApi?page=1
 * 创建应用接口       https://www.apiopen.top/createUserKey?appId=com.chat.peakchao&passwd=123456
 * 增加统计信息       https://www.apiopen.top/addStatistics?appKey=00d91e8e0cca2b76f515926a36db68f5&type=点击统计&typeId=1&count=2
 * 查询统计信息       https://www.apiopen.top/findStatistics?appKey=00d91e8e0cca2b76f515926a36db68f5
 * 用户注册接口       https://www.apiopen.top/createUser?key=00d91e8e0cca2b76f515926a36db68f5&phone=13594347817&passwd=123654
 * 用户登陆接口       https://www.apiopen.top/login?key=00d91e8e0cca2b76f515926a36db68f5&phone=13594347817&passwd=123456
 */
