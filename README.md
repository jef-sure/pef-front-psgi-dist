PEF Front
======

# Общий вид

Frontend состоит из нескольких компонент:

* `web-server` -- принимающий запросы от клиента и обслуживающий статичекские данные, а так же передающий динамические запросы приложению. На данный момент используется комбинация `nginx` + `uwsgi`, но возможна адаптация под любой способ, поддерживающий `PSGI`.
* `PSGI-демон` -- регулирующий работу PSGI-приложения. На данный момент это реализуется приложением `uwsgi`, но возможно использование модуля `mod_psgi` для `Apache2`.
* `PEF Frontend` -- фреймворк, принимающий динамические запросы согласно настройкам приложения
* Приложение, которое пользуется `PEF Frontend`-ом.

В этом документе будет описано функционирование PEF Frontend и примерная структура предполагаемого приложения.

# Структура приложения

Приложение может сконфигурировать работу фреймворка множеством способов, хотя некоторые предположения о приложении фреймворк всё равно делает. Если приложение следует предположениям, заложенным во фреймворке, то его конфигурация может занимать всего несколько строк. Приложение может описывать локальные обработчики, возвращающие данные, либо пользоваться бекендом типа PEF Core, тогда все запросы о данных будут переадресованы согласно настройкам.

## Файловая структура приложения

```
+ bin/
|- startup.pl
+ conf/
|+ My/
| - myapp.ini
| - nginx-handlers.conf
| - AppFrontConfig.pm
| + InFilter/
| + Local/
| + OutFilter/
+ log/
+ model/
+ templates/
++ var/
|+ cache/
|+ captcha-db/
|+ tt_cache/
|+ upload/
+ www-static/
|+ captchas/
```

## Назначение каталогов

* `bin` -- различные исполняемые файлы, необходимые для функционирования приложеиня.
* `conf` -- конфигурационные параметры и локальные фильтры и обработчики запросов
* `log` -- логи приложения
* `model` -- каталог с описанием доступных вызовов модели
* `templates` -- html-шаблоны
* `var` -- различные файлы, требуемые приложению во время работы
* `www-static` -- статическое содержимое приложения, отдаётся веб-сервером напрямую
* `www-static/captchas` -- сгенерированные капчи
* `var/cache` -- кешируемое сожержимое
* `var/captcha-db` -- база данных по сгенерированнвм изображениям капчи
* `var/tt_cache` -- кеш скомпилированных html-шаблонов
* `var/upload` -- файлы, которые были закачаны в приложение
* `conf/$AppNamespace/InFilter` -- фильтры данных, предаваемых в вызовы запросов к модели
* `conf/$AppNamespace/OutFilter` -- фильтры возвращаемых из запросов данных
* `conf/$AppNamespace/Local` -- локальные обработчики запросов приложения
* `conf/$AppNamespace/AppFrontConfig.pm` -- файл, содержащий конфигурацию приложения

# Конфигурирование приложения

В момент запуска, фреймворк `PEF Front` пытается самостоятельно угадать основные параметры приложения, а затем поверх этих параметров прочитать данные из модуля AppFrontConfig, который должен быть обязательно использован в программе, запускающей приложение, перед использованием запускающего модуля `PEF::Front::Route`.

Конфигурационный модуль `*::AppFrontConfig` может быть в любом пространстве имён, от его расположения автоматически отсчитываются каталоги InFilter, Local и OutFilter, а так же, пространство имён для соответствующих обработчиков в этих каталогах.

Обычно, запускающий приложение файл `startup.pl` должен выглядеть примерно так:

```
use My::AppFrontConfig;
use PEF::Front::Route ('/' => '/appIndex', qr'/index(.*)' => '/appIndex$1');
PEF::Front::Route->to_app();
```

Основной каталог приложения со структурой, подобной описанной выше, определяется на основе каталога, из которого было запущено приложение.

## Доступные параметры

* `app_namespace` -- пространство имён, в котором будут находиться фильтры и локальные обработчики
* `cache_expire` -- время хранения данных в кеше по умолчанию, если для ключа хранения не задано своё
* `cache_file` -- файл для кеша
* `cache_size` -- размер кеша
* `captcha_db` -- каталог, где будет находиться база капч
* `captcha_font` -- шрифт, используемый при рисовании капчи
* `captcha_secret` -- "секретное смещение" для генерируемых кодов md5, по которым сравнивается капча
* `db_name` -- имя локальной базы с сообщениями NLS и другой информацией
* `db_password` -- пароль локальной базы
* `db_user` -- пользователь локальной базы
* `db_reconnect_trys` -- количество попыток реконнекта, если вдруг коннект к базе пропал, между попытками интервал 1 сек.
* `default_lang` -- язык приложения по умолчанию
* `in_filter_dir` -- каталог с фильтрами данных, предаваемых в вызовы запросов к модели
* `location_error` -- страница с ошибкой, куда приложение может отправить браузер пользователя
* `model_dir` -- каталог с описанием вызовов модели
* `model_local_dir` -- каталог с локальными обработчиками
* `model_rpc` -- функция, возвращающая объект для связи с бекендом
* `model_rpc_admin_addr` -- адрес бекенда для администрирования
* `model_rpc_admin_port` -- порт бекенда для администрирования
* `model_rpc_site_addr` -- адрес бекенда для клиентского сайта
* `model_rpc_site_port` -- порт бекенда для клиентского сайта
* `no_multilang_support` -- флаг, что приложение не собирается поддерживать многоязыковую конфигурацию
* `no_nls` -- флаг, что приложению вообще не требуется трансляция сообщений
* `out_filter_dir` -- каталог с фильтрами возвращаемых из запросов данных
* `template_cache` -- кеш скомпилированных html-шаблонов
* `template_dir` -- html-шаблоны приложения
* `template_dir_contains_lang` -- флаг, обозначающий, что шаблоны для разных языков будут лежать в разных каталогах по соответствующему сокращению языка
* `upload_dir` -- каталог для закачиваемых файлов в приложение
* `url_contains_lang` -- флаг, обозначающий, что URL в префиксе содержит сокращённоое название языка
* `www_static_captchas_dir` -- каталог со сгенерированными капчами
* `www_static_dir` -- каталог со статическим содержимым

_Замечение:_ параметры `model_local_dir`, `in_filter_dir` и `out_filter_dir` вычисляются автоматически, если их перенести, то это потребует заметных изменений в логике поиска модулей, на текущий момент их самостоятельное конфигурирование не работает.

Для изменения параметров, в модуле `*::AppFrontConfig` необходимо определить функцию с соответствующим названием. Например:

```
sub db_user                    {"scott"}
sub db_password                {""}
sub db_name                    {"tiger"}
```

_Замечание:_ в модуль `*::AppFrontConfig` происходит обратный реэкспорт всех вычисленных параметров, поэтому возможно писать параметры на их основе:
```
sub www_static_captchas_dir { www_static_dir() . "/images/captchas" }
```

## Функция экспорта пользовательских параметров
`PEF::Front::Config` можно использовать вместо `Exporter` для указания пользовательских параметров в тех обработчиках, что используются локально в приложении. Например:
```
our @EXPORT = qw(avatar_images_path);
sub avatar_images_path () { www_static_dir() .'/images/avatars' }
```

Затем в локальном модуле `My::Local::AvatarUpload`:
```
package My::Local::Avatar;
use PEF::Front::Config;

sub upload {
	my ($msg, $def) = @_;
# ...
	my $upload_path = avatar_images_path;
# ...
	return {
		result => "OK",
	};
}
```

`use PEF::Front::Config` в локальном модуле даёт доступ ко всем параметрам фреймворка и экспортированным параметрам приложения.

_Замечание:_ писать `use PEF::Front::Config` в модуле `*::AppFrontConfig` нельзя! Это порождает циклическую зависимость: для компиляции модуля `*::AppFrontConfig` понадобится модуль `PEF::Front::Config`, которому, в свою очередь, нужен уже ранее загруженный модуль `*::AppFrontConfig`.

## Конфигурационные данные с параметрами

Некоторые функции принимают значения, но большинство нет. Следующие функции работают с параметрами:

* `model_rpc($model)` -- принимает значение параметра `model` из соответствующего файла конфигурации вызова
* `template_dir($hosname, $lang)` -- принимает параметром имя сайта и язык, чтобы вернуть соответствующий каталог с шаблонами

# Пример применения

В данном разделе описывается один конкретный из множества вариантов способ применения фреймфорка.

## Компоненты
### nginx

Примерный файл его конфигурации выглядит вот так:

```
server {
	listen 80 default_server;
	root /var/www/www.example.com/www-static;
	index index.html index.htm;
	client_max_body_size 100m;
	server_name www.example.com;
	location =/favicon.ico {}
	location /css/ {}
	location /jss/ {}
	location /fonts/ {}
	location /images/ {}
	location /styles/ {}
	location / {
	    include uwsgi_params;
	    uwsgi_pass 127.0.0.1:3031;
	    uwsgi_modifier1 5;
    }
	location ~ /\. {
		deny all;
	}
}
```

Некоторые пути доступа отдаются `nginx`-ом самостоятельно, не делая запроса в приложение, `nginx` это сделает лучше любого другого варианта.

### uwsgi

Примерный файл конфигурации для демона `uwsgi` выглядит так:

```
[uwsgi]
plugins = psgi
socket = 127.0.0.1:3031
chdir = /var/www/www.example.com
psgi = bin/startup.pl
master = true
processes = 8
stats = 127.0.0.1:5000
perl-no-plack = true
cheaper-algo = spare
cheaper = 2
cheaper-initial = 5
cheaper-step = 1
```

### Фреймворк

Фреймворк устанавливается обычным make install способом.

### Приложение

В случае, если приложение максимально похоже на то, что предполагается фреймворком, то конфигурирование требуется минимальное. Достаточно только наполнить проект "содержанием".

## Запуск

После запуска веб-сервера и uwsgi, приложение становится полностью функциональным.

# Функционирование фреймворка
## Шаблоны

Для шаблонизации используется диалект TemplateToolkit, реализованный модулем Template::Alloy. При генерации шаблона доступны данные, переданные при вызове страницы, а так же, с помощью добавленных методов можно получить дополнительные данные.

Например:

```
[% news = "get all news".model(limit => 3) %]
<section class="news">
  [% FOREACH n IN news.news %]
    [% IF loop.index != 2 %]
      <article class="ar_news">
    [% ELSE %]
      <article class="ar_news ar_none">
    [% END %]
        <h3>[% n.title %]</h3>
        <p>[% n.body %]</p>
        <div class="button">Next<div class="sm">&gt;</div></div>
      </article>
  [% END %]
</section>
```

В строке `[% news = "get all news".model(limit => 3) %]` идёт вызов "модели", метод `get all news` с параметром `limit`=3, по возвращённому списку новостей строится содержимое части страницы.

Шаблоны располагаются в каталоге `template_dir`, называются $template.html и доступны по пути /app$Template. Достаточно положить файл в этот каталог и автоматически появляется соответствующий путь.

### Доступные в шаблонах методы

Помимо методов, которые реализованы в Template::Alloy, доступны так же следующие методы:

* `"method".model(param => value)` -- вызов метода модели
* `msg("msgid")` -- преобразование идентификатора сообщения в показываемое сообщение, возможно с учётом языка
* `uri_unescape("hello%20world")` -- преобразование из uri-escaped формы в обычный текст
* `strftime('%F', gmtime)` -- получение строки даты и времени по формату.
* `gmtime(time)` -- функция, возвращающая массив данных даты и времени GMT, подходящий функции `strftime`
* `localtime(time)` -- то же самое, что и `gmtime`, но формат данных локального (для сервера) времени
* `response_content_type("text/plain")` -- установка заголовка Content-Type ответа
* `request_get_header("user-agent")` -- получение заголовка, пришедшего в запросе
* `response_set_cookie(hello=>"world")` -- установка куки в ответе
* `response_set_status(403)` -- установка кода статуса ответа

### Доступные в шаблонах данные

Шаблон вызывается со следующими данными:

* `ip` -- IP клиента
* `lang` -- сокращённое название языка, на котором генерируется шаблон для клиента
* `hostname` -- доменное имя, по которому пришёл запрос
* `path_info` -- локальный путь, по которому запрошен шаблон
* `form` -- хеш данных запроса, объединённые из строки запроса и переданны данных в форме, если она была
* `cookies` -- хеш кук
* `template` -- имя обрабатываемого шаблона
* `scheme` -- схема `http` или `https`
* `time` -- текущий счётчик UNIX-времени
* `gmtime` -- массив данных текущего времени GMT, подходящий функции `strftime`
* `localtime` -- то же, что и `gmtime`, но для локального времени

## Вызовы модели

Возможно использование нескольких моделей одновременно. Для вызова модели необходимо его описание. Описание каждого вызова располагается в `model_dir`, по одному файлу на каждый вызов. Имя файла формируется из формы `CamelCase` названия метода и расширения .yaml: `get all news` => `GetAllNews.yaml`.

Файлы имеют YAML-структуру, описание вызова располагается в самом первом документе, если в файле не один документ. Так же существует файл -base-.yaml, в котором можно описать все необходимые данные о проверке параметров, а затем это использовать в описании конкретного вызова просто указанием ссылки.

Например, `-base-.yaml`:
```
params:
    ip:
        regex: ^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$
        value: defaults.ip
    limit:
        regex: ^([123456789]\d*)$
        optional: true
        max-size: 3
        default: 5
    offset:
        regex: ^(0|[123456789]\d*)$
        optional: true
        default: 0
        max-size: 10
    textarea:
        filter: [ s/</&lt;/g, s/>/&gt;/g ]
```

`GetAllNews.yaml`:

```
params:
    ip: $ip
    limit: $limit
    offset: $limit
model: admin
allowed_source: [submit, ajax, template]
```

Благодаря использованию `-base-.yaml`, описание параметров конкретных вызовов заметно сокращается, а так же упрощается управление ими.

### Формат описания вызова модели

#### Параметры

Ключ params описывает передаваемые в метод параметры. Каждый параметр может иметь атрибуты или просто описывать regexp для проверки допустимости. Атрибуты бывают следующими:
* `regex` -- задаёт проверочное регулярное выражение.
* `captcha` -- задаёт проверочное поле формы для капчи
* `type` -- тип значения. для случаев сложных данных, например, когда передаётся массив, хеш или файл.
* `max-size` -- максимальный размер для скаляра, массива или количества ключей хеша.
* `min-size` -- минимальный размер для скаляра, массива или количества ключей хеша.
* `can` или `can_string` -- перечень строковых значений, которые может принимать параметр.
* `can_number` -- перечень допустимых числовых значений.
* `default` -- значение по умолчанию. может быть заданным значением или передано в запросе.
* `value` -- то же, что и default, но не может быть передано в запросе. взаимоисключающе с default.
* `optional` -- параметр не обязателен. кроме значений true/false может принимать специальное значение empty, что означает, что метод не обязателен не только, когда его совсем не передали, но и когда он не заполнен.
* `filter` -- фильтрация входящих данных. можно указать одну замену с regexp, список замен с regexp-ами или функцию из модулей фильтрации входящих данных

##### Значения default/value

Специальные префиксы `defaults`, `headers`, `cookie` могут быть использованы в значении параметров `default` или `value`.

* `defaults.param` -- параметр из хеша defauts. Возможные параметры: `ip`, `lang`, `hostname`, `path_info`
* `headers.header` -- заголовок из запроса
* `cookies.cookie` -- кука из запроса


#### Лишние параметры

Если в запросе передано больше параметров, чем нужно, то есть три варианта поведения:
* `ignore` -- проигнорировать все лишние параметры, в ядро ничего лишнего не будет передано.
* `pass` -- пропустить параметры в ядро без проверок.
* `disallow` -- при наличии лишних параметров проверка будет неуспешна, никакого вызова ядра не будет, будет сообщение об ошибке.
Вариант действия выбирается ключом `extra_params`.

#### Метод вызова
Параметр `model` задаёт вызываемую модель. Модель может быть локальной или удалённой. Локальная модель задаётся квалифицированным именем вызываемой функции, исключая всё, что входит в `app_namespace`, все предыдущие недостающие части пространства имён добавляются фреймворком из параметра `app_namespace` самостоятельно. Локальные обработчики лежат в каталоге `model_local_dir`. Фреймворк так же содержит несколько полезных обработчиков, которые можно указать в локальной модели.

Удалённая модель может быть определена самостоятельно или по схеме site/admin, когда одна модель для администрирования, другая для клиентского сайта. Для функционирования используются параметры `model_rpc*`.

#### Фильтры
##### Фильтры входящих данных
Атрибут `filter` задаёт способ фильтрации данных. Например:

model/Test.yaml:
```
params:
    title:
        filter: [ s/</&lt;/g, s/>/&gt;/g ]
    text:
        filter: Text::filter
model: Test::test
```

Local/Test.pm:
```
package My::Local::Test;

sub test {
	my ($msg, $def) = @_;
	return {
		result => "OK",
		data   => [1, 2],
		ip     => $def->{ip},
		title  => $msg->{title},
		text   => $msg->{text}
	};
}

1;
```

InFilter/Text.pm:
```
package My::InFilter::Text;

sub filter {
	my ($field, $def) = @_;
	$field =~ s/</&lt;/g;
	$field =~ s/>/&gt;/g;
	return $field;
}

1;
```

`filter` может быть одним выражением замены, списком выражений замены или функцией, которая каким-то образом может изменить содержимое поля. Выражение замены может быть одним из операторов: `s`, `tr`, `y`. В этом примере параметры `title` и `text` вызова модели "test" фильтрутются одинаково, но функция обладает бОльшей гибкостью и имеет доступ к уже сформированным данным `defaults`.

##### Фильтры отправляемых ответов
В секции `result` у конкретного кода ответа можно задать дополнительный атрибут `filter`, что будет означать дополнительную обработку данных перед отправкой. Фильтр представляет собой функцию в модуле в иерархии PEF::OutFilter::*, которой передаются значения ($response, $defaults), на основании которых она может изменять переданный хеш $response. Смысл в получении каких-либо данных из модели и преобразования их к новому формату, например XML, CSV, XLS и подобными.
Например:

model/Test.yaml:
```
params:
    title:
        filter: [ s/</&lt;/g, s/>/&gt;/g ]
    text:
        filter: Text::filter
result:
    OK:
        filter: TestOut::test
model: Test::test
```

OutFilter/TestOut.pm:
```
package My::OutFilter::TestOut;

sub test {
	my ($resp, $def) = @_;
	push @{$resp->{data}}, 3, 4, 5 if exists $resp->{data};
}

1;
```

#### Как работает капча

Использования локального обработчика на примере капчи.

Captcha.yaml:
```
---
params:
    width:
        default: 35
    height:
        default: 40
    size:
        default: 5
extra_params: ignore
model: PEF::Front::Captcha::make_captcha
```

SendMessage.yaml:
```
---
params:
    ip: $ip
    email: $email
    lang: $lang
    captcha_code:
        min-size: 5
        captcha: captcha_hash
    captcha_hash:
        min-size: 5
    subject: $subject
    message: $message
result:
    OK:
        redirect: /appSentIsOk
model: site
allowed_source:
    - submit # ajax, submit, template
    - ajax
```

В шаблоне присутствует примерно следующий код:
```
<form method="post" action="/submitSendMessage">
Captcha:
[% captcha="captcha".model %]
<input type="hidden" name="captcha_hash" value="[% captcha.code %]">
<img src="/captchas/[% captcha.code %].jpg">
<input type="text" maxlength="5" name="captcha_code">
...
</form>
```

Капча формируется на фронтенде и там же она проверяется перед посылкой данных в модель. Проверка капчи деструктивна, проверить её правильность возможно только один раз, в следующий раз код, который только что был правильным, уже будет использован и его проверка не пройдёт. Вызов "captcha".model формирует картиинку, вносит информацию о ней в базу данных и отдаёт ссылку на неё. Если требуется перезагрузка картинки, то на ajax делается вызов /ajaxCaptcha, информация из которого используется для прописывания нового содержимого поля captcha\_hash. В момент вызова /submitSendMessage будет произведена автоматическая проверка соответствия капчи. Для случая, когда сообщение отправляется зарегистрированным пользователем, можно капчу не требовать, но параметр captcha\_code всё равно необходим. В этом случае предусмотрено специальное значение "nocheck", чтобы фронтенд не проверял капчу для зарегистрированного пользователя, в этом случае проверка переносится в ядро. Модель должно увидеть, что пришло сообщениие от незарегистрированного пользователя и с непроверенной капчей и среагировать соответственно.

### AJAX

В случае вызова по URL доступны следующие префиксы:
* `ajax` -- в этом случае ответ ядра будет передан в виде JSON-текста, обработка результатов не будет учитывать возможные редиректы.
* `submit` -- в этом случае ответом подразумевается редирект на новый URL или прямой ответ значения, например для ответа платёжным системам.
* `get` -- так же, как и submit, но может принимать дополнительные параметры как части URL. Предназначено для ссылок в письме или других запросов. Например https://domain.com/getConfirmNewEmail/2134242342423 -- здесь параметр, если не указано его имя, будет называться cookie. Можно передавать несколько параметров, которые разделяются символом '/', имя параметра от значения отделяется символом '-'.

### File upload

Когда происходит закачка файлов на сервер, они сохраняются в каталоге `upload_dir`/$$ -- в подкаталоге по номеру рабочего процесса, чтобы между разными процессами не было пересечения файлов.
В данных формы в соответствующем поле будет содержаться объект `PEF::Front::File`, в котором можно узнать все необходимые данные о файле, чтобы его в дальнейшем обработать: перенести в постоянное место хранения или ещё как-либо использовать.
По окончании обработки запроса, если файл не был куда-либо перемещён, то в момент удаления экземпляра объекта будет удалён и файл, на который он указывает.

Если в данных формы перед полем `file_field`, содержащим файл, было задано поле `file_field_id`, то значение этого поля используется как идентификатор файла, который может использоваться для запросов отдельным AJAX-обработчиком о прогрессе закачивания файла.
Для этого нужно описать соответствующий вызов модели и в качестве `model` указать `PEF::Front::UploadProgress`, в параметрах должны быть `ip` и `id`, где `id` -- значение из поля `file_field_id`. В ответе будут параметры done и size: `{result => 'OK', done => $done, size => $size}`.
Если файл уже был закачан и прогресса по нему больше не может быть или не закачивался вообще, то ответом будет `{result => 'NOTFOUND', answer => 'File with this id not found'}`.

_Важное замечание:_ В момент закачивания значение ответа size известно приблизительно или не верно вообще, поэтому не стоит на него полагаться полностью.

### Кеш ответов ядра
Некоторые данные от ядра могут меняться редко, для этого предусмотрено кеширование. Кешированием управляет ключ cache. У него есть два атрибута:
* key -- значение или массив, описываются параметры, от которых зависит выборка.
* expires -- как долго можно считать значение актуальным. Разбор этого параметра ведётся модулем Time::Duration::Parse.
Пример описания ключа:
```
cache:
    key: method
    expires: 1m
```

## Обработка результата ответа
Ключ result определяет действия, который необходимо совершить при получении ответа от ядра. Ядро возвращает, как правило, следующие варианты ответа:
```
{
    result => "OK",
...
}
либо
{
    result => "SOMEERRCODE",
    answer => 'Some $1 Error $2 Message $3',
    answer_args => [$some, $error, $params],
...
}
```

На основании ключа ответа result, выбирается действие из соответственного описания result. Плюс есть специальное описание DEFAULT, которое используется, когда никакое другое не подошло. В аттрибутах действия можно опиисать:
* `redirect` -- временный редирект браузера для submit и get запросов.
* `set-cookie` -- установить куку. ключами выступают названия устанавливаемых кук, которым можно добавить соответсвтующие атрибуты 
* `unset-cookie` -- сбросить куку браузера.
* `filter` -- специальный фильтр, обрабатывающий ответ
* `answer` -- прямое значение ключа answer в ответе
* `set-header` -- устанавливает заголовок в ответе
* `add-header` -- добавляет заголовок. в отличии от `set-header`, можно в ответе выдать несколько заголовков с одинаковым именем.

_Замечание:_ при установке куки, атрибут `secure` может быть вычислен автоматически исходя из схемы запроса: `https` значит secure =>, `http` значит не устанавливать признак `secure`

## Рутинг

Стандартная схема путей доступа фреймворка выглядит так:
* `/app$Template` -- шаблонизированные страницы
* `/ajax$Method` -- вызов метода модели аяксом, результат JSON-сообщение
* `/submit$Method` -- то же, что и ajax, но подразумевается в ответе перенаправление на новое место или возврат информации, вроде HTML
* `/get$Method/$id...` -- то же, что и submit, но подразумевается наличие дополнительных параметров в пути

Вся эта замечательная схема не всем нравится. Иногда хочется иметь "красивые" пути, вроде `/product/smartphone/Samsung` вместо `/appProduct?id_product=9300`. Для преобразования путей, что используются в браузере в те, что полнимаются во фреймворке, используется рутинг.

Рутинг задаётся до старта приложения. Его можно импортировать в модуль `PEF::Front::Route` или добавить через функцию `PEF::Front::Route::add_route`:
```
use PEF::Front::Route ('/index' => ['/appIndex', 'R']);
```

Рутинг всегда задаётся парами: правило => назначение. Назначение может иметь дополнительные флаги. Флаги могут иметь параметр через знак `=`. Флаги разделяются запятыми. Поддерживаются следующие флаги:
* `R` -- редирект. Можно задать параметром статус редиректа. Например, `R=301` для перманентного редиректа
* `L` -- это правило последнее, если сработало. Можно задать статус ответа, если не передан полный ответ `$http_response`. Например, `L=404`, чтобы прервать обработку и показать пользователю, что информация не найдена
* `RE` -- флаги для Regexp, Например, `RE=g`

Поддерживаются следующие комбинации типов правил и назначения:
* Regexp => строка. В этом случае преобразование будет иметь вид `s"$regexp"$string"$flags`. Например: qr"/index(.*)" => '/appIndex$1'
* Regexp => CODE. При совпадении `m"$regexp"$flags` будет вызвана указанная функция с параметрами ($request, @params), где @params -- массив совпавших групп из сработавшего $regexp
* строка => строка. Проверяется буквальное совпадение строки и если произошло, то путь заменяется на другую строку
* строка => CODE. Проверяется буквальное совпадение строки и если произошло, вызывается функция с параметром ($request)
* CODE => строка. В случае, когда фунцкия возвращает истину, путь заменяется на строку
* CODE => CODE. Если правило сработало, то в функцию назначения передаются параметры ($request, @params), где @params -- массив, который вернула функция совпадения
* CODE => undef. В этом случае функция, отвечающая за правило, является так же и функцией, возвращающей новый путь

Функции назначения могут вернуть простую строку или массив, в котором будут:
* `[$dest_url]`
* `[$dest_url, $flags]`
* `[$dest_url, $flags, $http_response]`

В случае флагов `R` или `L` это правило будет последним, дальнейших преобразований пути не происходит.

Итогом преобразования пути должен быть путь из "стандартной схемы" или редирект.