# 프로듀서 개요

이벤트 프로듀싱 과정 
1. 로직을 수행하고 있는 스레드에서 kafka의 send 메서드 호출
2. serializing, partitioning, compressing 수행
4. Record Accumulator 에 batch로 저장 
   5. send 메서드로는 하나씩 호출하더라도 Accumulator 에 batch 로 한꺼번에 전송 (여러 배치로도 전송한다.)
5. 별도의 스레드 (Sender)에서 브로커로 전송 

# 카프카 프로듀서 생성하기

프로듀서 생성 예시코드
```
Properties props  = new Properties();
props.setProperty(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
props.setProperty(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
props.setProperty(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
props.setProperty(ProducerConfig.DELIVERY_TIMEOUT_MS_CONFIG, "50000");
props.setProperty(ProducerConfig.ACKS_CONFIG, "0");
props.setProperty(ProducerConfig.BATCH_SIZE_CONFIG, "32000");
props.setProperty(ProducerConfig.LINGER_MS_CONFIG, "20");

KafkaProducer<String, String> kafkaProducer = new KafkaProducer<String, String>(props);
```

### 메세지 전송 방법
1. fire and forget - 전송하고 성공 여부를 확인하지 않는다.
2. synchronous send - 전송하고 Future의 get 메서드를 통해 작업 완료를 확인하다.
3. asynchronous send - 메세지 전송을 하고 돌아가고 응답이 올 경우 콜백함수가 작동한다.
   
### synchronous send 
Future.get() 메서드를 통해 동기적으로 응답을 가져올 수 있다.

위 메서드는 메세지가 성공적으로 전송하지 않았을 때 예외를 반환한다. 예외에는 두 가지 종류의 예외가 있는데
1. 재시도 가능한 예외 (리더 브로커가 아닌 브로커에게 이벤트 전송 (메타 정보 업데이트 후 정상 전송 가능))
2. 재시도 불가능한 예외 (메세지 크기가 너무 클 경우)


### asynchronous send
KafkaProducer의 send() 메서드를 수행하는 스레드와 Accumulator에 모아놓은 배치를 실제로 브로커로 전송하는 sender
스레드가 있다.

Sender의 스레드는 실제로 배치를 브로커로 전송, Broker로 부터 응답이 왔을 때 콜백함수 수행이나 응답 결과를 Future를 통해
사용자에게 전달한다.

(그래서 콜백함수에서 블로킹 작업을 하는 것은 지양하거나 별도의 스레드에서 수행하게 해야한다.)


# 프로듀서 설정하기

### client.id 
브로커가 프로듀서가 보내온 메세지를 서로 구분하기 위해 사용하는 문자열 

### acks
1. acks = 0 -> fire and forget (메세지가 성공적으로 전달되었다고 간주하고 응답을 기다리지 않는다.) 
2. acks = 1 -> 리더 브로커가 메세지를 받는 순간 성공했다는 응답을 받는다. 
   3. 만약 리더에게 메세지를 보내고 응답을 받았는데 그 순간 크래시나 나면 복제가 안되고 새 리더가 선출되기 때문에 유실이 발생할 수 있다.
4. acks = all -> 모든 레플리카에 전달되었다는 응답을 받아야 성공했다는 응답을 받는다.


# 메세지 전달 시간

### max.block.ms
send()를 호출하여 partitionsFor()가 호출되었을 때 버퍼가 꽉차있거나 메타 정보를 사용할 수 없을 때
대기 시간으로 넘어서면 예외가 발생한다.

### delivery.timeout.ms
send()를 통해 이벤트가 배치에 적재되어서 send()가 문제없이 리턴된 시점에서부터 브로커로부터 정상적으로 응답을 받거나 전송을
포기하게 되는 시점까지의 제한시간

delivery.timeout.ms >= linger.ms + retry.backoff.ms + request.timeout.ms 이 되게 지정해줘야 한다.

브로커가 크래시가 난 경우 리더 선출에 걸리는 시간을 고려하여 delivery.timeout.ms를 설정하면 그 시간동안 계속
재시도를 하여 리더가 다시 선출되면 처리가 가능해진다.

### request.timeout.ms
메세지를 보내고 나서 브로커로부터 응답을 받기 위해 얼마나 기다릴지에 대한 제한시간

### retries, retry.backoff.ms
브로커로부터 예외를 받았을 경우 재시도 횟수와 재시도 사이 간격 시간

### linger.ms
배치를 전송허기 전까지 대기시간

프로듀서의 경우 현재 배치가 가득 차거나 linger.ms에 설정된 제한 시간이 되었을 때 메세지 배치를 전송한다.

### buffer.memory, compression.type, batch.size
- buffer.memory : 메세지를 전송하기 전 대기시키는 버퍼의 크기 
  - send() 가 호출되고 버퍼가 가득 차있을 때 해당 설정 시간만큼 대기한다.
- compression.type : 기본적으로는 메세지는 압축되지 않고 전달되는데 type 지정을 통해 압축을 하여 전송할 수 있다.
- batch.size : 프로듀서는 배치 단위로 이벤트를 보내는데 이때 배치 사이즈
  - 배치 사이즐르 크게한다 해도 일정 시간이 지나면 다 안차도 전송이 되기 때문에 전송 지연이 크게 발생하지 않는다.
  - 너무 작게하면 자주 보내게 되어 오버헤드가 발생할 수 있다.

### max.in.flight.request.per.connection
프로듀서가 브로커로부터 응답을 아직 받지 못했을 때 전송할 수 있는 메세지의 수이다. 해당 값을 올려서 설정하면 메모리 사용량이
많아지나 처리량이 증가한다. (기본 값은 5이다.)

해당 값이 1 이상이 되면 순서 보장이 되지 않는다.
1. A 메세지를 보냄
2. B 메세지를 보냄 
3. A 메제지 전송 실패함
4. A 메세지를 재전송함

이러한 상황이 발생하면 큐에는 B, A 순서대로 들어갔기 때문에 순서가 보장이 되지 않는다. 이때 enable.idempotence = true
설정을 통해 순서 보장이 가능하다. (재전송시 1번만 실행도 보장해준다.)

### max.request.size, send.buffer.byte, enable,idempotence
- max.request.size : 프로듀서가 전송하는 쓰기 요청의 크기
- receive.buffer.byte : 데이터를 보낼 때 소켓이 사용하는 TCP 송신 버퍼의 크기
  - 값이 -1일 때는 운영체제의 기본 값을 사용한다.
  - 프로듀서, 브로커가 각자 다른 데이터 센터에 위치한 경우 해당 값을 올려잡는게 좋다.

### enable.idempotence
해당 설정이 true이면 프로듀서는 레코드를 보낼 때 순차적인 번호를 붙인다. 그래서 브로커는 같은 번호를 2개 받아도 하나만 처리하게 된다.
- max.in.flight.request.per.connection = 5 이하
- retires 1 이상
- acks = all

이렇게 설정되어야 해당 설정을 true로 설정할 수 있다.

# 시리얼라이저

### apache avro
json 과 비슷한 형식으로 정의되는데 스키마가 존재한다. 프로듀서에서 레코드 포멧을 업데이트하더라도 기존 스키마와 호환이 되고
새로운 스키마도 업데이트 없이 읽을 수 있다는 장점이 있다.

에이브로는 레코드를 읽을 때 스키마를 필요로 하기 때문에 ***스키마 레지스트리*** 라는 아키텍쳐 패턴을 사용한다.

사용되는 모든 스키마를 레지스트리에 저장하고, 레코드에는 고유 식별자만 추가하여 deserializer는 식별자를 통해 스키마를
레지스트리에서 가져오고 deserialize를 한다.

에이브로 serializer는 pojo가 아닌 avro 객체만 생성할 수 있다. 해당 객체는 getter, setter가 함께 생성된다.

# 파티션
레코드에 구성요소중 하나인 키는 해당 레코드가 어느 파티션에 할당 될지 판단하는데 사용되기도 한다.

만약 키가 null일 경우에는 파티션중 하나가 랜덤으로 결정되는데 라운드 로빈 알고리즘이 사용된다. 아파치 카프카 2.4 프로듀서
부터는 key가 null일 경우 stikcy 라운드 로빈 알고리즘을 사용한다.

sticky 라운드 로빈이란 프로듀서가 메세지 배치를 채울 때 현재 배치를 다 채우고 다음 배치를 채움으로 요청 횟수를 줄여서
지연시간, 브로커의 cpu 사용량을 줄이는 알고리즘이다.

키 값이 있다면 해당 키를 해쉬화 하여 그에 맵핑된 파티션에 할당한다.

### 커스텀 파티션

```
public class CustomPartitioner implements Partitioner {
    public static final Logger logger = LoggerFactory.getLogger(CustomPartitioner.class.getName());
    private final StickyPartitionCache stickyPartitionCache =  new StickyPartitionCache();
    private String specialKeyName;

    @Override
    public int partition(String s, Object o, byte[] bytes, Object o1, byte[] bytes1,
        Cluster cluster) {
        List<PartitionInfo> partitionInfos = cluster.partitionsForTopic(s);
        int numPartitionSize = partitionInfos.size();
        int numSpecialPartitions = (int)(numPartitionSize * 0.5);
        int partitionIndex = 0;

        if (bytes == null) {
            stickyPartitionCache.partition(s,cluster);
        }

        if(s.equals(specialKeyName)) {
            partitionIndex = Utils.toPositive(Utils.murmur2(bytes1) % numSpecialPartitions);
        } else {
            partitionIndex = Utils.toPositive(Utils.murmur2(bytes)) % (numPartitionSize - numSpecialPartitions);
        }

        logger.info("key: {} is sent to partition : {}", o.toString(), o1.toString());
        return partitionIndex;
    }
```
이런식으로 custom partition을 정의할 수 있다. (특정 레코드에 대한 요청이 많아 그 레코드에 대한 서버를 특정하고 싶은 경우)

# 헤더
데이터가 생성된 곳, 메세지의 전달 내역 등과 같은 메타 정보를 주로 헤더에 저장한다. 헤더에 저장함으로 메세지 파싱없이 필요 정보를
얻을 수 있다.

# 인터셉터
사용하고 있는 모든 레코드 이벤트에 대하여 공통적인 로직을 추가해야 하거나, 클라이언트 코드를 수정하지 않고 작동을 변경해야 할 때
인터셉터를 사용할 수 있다.

```
ProducerRecord<K, V> onSend(ProducerRecord<K, V> record); -> 브로커로 보내기 전 (직렬화 되기 전)
void onAcknowldge(RecordMetaData medaData, Exception ex); -> 브로커가 보낸 응답을 클라이언트가 받았을 때 
```

```
export CLASSPATH=$:~./target/Interceptor-1.0-SNAPSOHT.jar

interceptor.class=com.test.examples.interceptors.Interceptor 
counting.interceptor.window.size.ms=10000

bin/kafka-console-producer.sh --broker-list localhost:9092 --topic it --producer.config producer.config 
```





