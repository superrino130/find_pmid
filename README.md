# find_pmid
jPOST id から PubMed id を探索するためのRuby製の補助ツールです。
# gem
下記のgemが必要です。
```ruby
gem "bio"
gem "mechanize"
```
# フロー
## 1
jPOSTrepoサーバのxmlデータ(ex.https://repository.jpostdb.org/xml/JPST000855.0.xml )を読み込み、`PXID` `CreatedDate` `PrincipalInvestigator` `Submitter` `Keywords` などを取得します。

```ruby
JPST000855
title:SCFCyclin F targets the metabolic protein Sirtuin 5 for ubiquitination
PXD019396  pi:Matthew D. Hirschey[AU] sm:Paul Grimsrud[AU]
keywords:["Cyclin F (CCNF)", "Sirtuin 5 (SIRT5)", "cell cycle", "ubiquitin", 
"metabolism"]
```
## 2
`google scholar`で`jPOST id` `PXID`を使用し検索を行います。
(ex.https://scholar.google.com/scholar?hl=ja&q=JPST000855+OR+PXD019396)
（短時間で検索を行いますと、ロボットではないことの証明を要求されます）
```ruby
https://www.ncbi.nlm.nih.gov/pmc/articles/pmc8093487/
https://journals.asm.org/doi/abs/10.1128/MCB.00269-20
```
## 3
`PubMed`で`PI名` `SM名` `CreatedDate`の１か月前から１３か月後の`PubMed id`を取得します。
`PubMed id`から`Abstract`を取得し、`Keywords`の一致する点数を数えます。
`Keywords`が一致しない`PubMed id`は非表示となります。
`pi+sm`は双方の名前が論文に記載されていたケースになります。
```ruby
**PubMed**
2020-04-01 - 2021-06-01
["33993056", "33798408", "33466329", "33243834", "33188857", "33168699", "32865009", "32691018", "33529682", 
"32660330"]
["Cyclin F (CCNF)", "Sirtuin 5 (SIRT5)", "cell cycle", "ubiquitin", "metabolism"]

http://www.ncbi.nlm.nih.gov/pubmed/33168699
["pi+sm", "Sirtuin 5 (SIRT5)", "cell cycle", "ubiquitin", "metabolism"]
http://www.ncbi.nlm.nih.gov/pubmed/32691018
["pi", "metabolism"]
http://www.ncbi.nlm.nih.gov/pubmed/33466329
["pi", "metabolism"]
http://www.ncbi.nlm.nih.gov/pubmed/33243834
["pi", "metabolism"]
http://www.ncbi.nlm.nih.gov/pubmed/32660330
["sm", "metabolism"]
```
# 補足
main.rb: 一件ずつ検索を行います。
main_all.rb: `jpostid.txt`に記載された`jPOST id`を連続して検索を行い(件数が多いとgoogleにはじかれます)、`result.txt`に検索結果を出力します。

