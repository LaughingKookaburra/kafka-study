### 카프카 데이터 전송때 수행되는 작업의 순서

1. ProducerRecord 객체 생성
    1. topic , value : 필수
    2. key, partition : optional
2. ProducerRecord 전송하는 API 호출
    
    key-value 를 직렬화, 바이트 배열로 변환
    
3. Partition 지정하지 않았다면, partitioner 에게 보낸다
    
    보통 ProducerRecord 객체의 키 값으로 결정
    
4. topic, partition 이 확정되면, producer 는 이 레코드를 같은 토픽 파티션으로 전송될 레코드들을 모은 record batch 에 추가, 별도의 스레드가 이 레코드 배치를 적절한 카프카 브로커에게 전송
5. 브로커가 파티션 안에서의 record offset 을 담은 RecordMetadata 객체를 리턴

```java
public class ProducerRecord<K, V> {
    private final String topic;
    private final Integer partition;
    private final Headers headers;
    private final K key;
    private final V value;
    private final Long timestamp;
}
```

```java
public final class RecordMetadata {
    public static final int UNKNOWN_PARTITION = -1;
    private final long offset;
    private final long timestamp;
    private final int serializedKeySize;
    private final int serializedValueSize;
    private final TopicPartition topicPartition;
}
```

## Producer 생성

Kafka Producer는 아래 3가지 필수값을 갖는다.

1. **bootstrap.servers**
    
    브로커의 host:port 목록
    
2. **key.serializer**
    
    record의 키 값을 직렬화하기 위한 Serializer 클래스의 이름
    
    키값없이 value 값만 보낼 때는 VoidSerializer 사용해 키값을 Void로 설정 가능
    
3. **value.serializer**
    
    밸류값으로 쓰일 객체를 직렬화하는 클래스 이름
    

### 메세지 전송 방법

1. Fire and foreget
    
    전송만 하고, 성공/실패 여부는 신경쓰지 않는다
    
    producer 는 자동으로 전송 실패시 재전송을 시도하기에 대부분은 성공적으로 전달된다
    
    재시도 불가 에러 / 타임아웃 발생시 메세지는 유실되고, 아무런 정보를 알 수 없다
    
2. synchronous send
    
    기본적으로는 async 지만, get()를 호출해서 실제 성공 여부를 확인할 수 있다
    
3. asynchronous send
    
    콜백 함수와 함께 send message 를 호출하면, 자동으로 콜백 함수가 호출된다
    

```java
// send method
public Future<RecordMetadata> send(ProducerRecord<K, V> record) {
    return this.send(record, (Callback)null);
}
```

Exception

- message serialization 실패시 : `SerializationException`
- 버퍼 가득 찰시 : `TimeoutException`
- thread에 interrrupt 가 걸릴시 : InterruptException

### 동기식

```java
ProducerRecord<String, String> producerRecord = ???
try {
	producer.send(record).get();
} catch (Exception e) {
	//
}
```

producer 에는 2종류 에러가 있다

1. 재시작 가능한 에러
    
    e.g.) 연결에러, “해당 파티션의 리더가 아닐 경우”, …
    
    자동으로 재시작하도록 KafkaProducer 를 설정 가능
    
    재시작 횟수 소진되고서도 에러가 나면 재시도 가능한 에러가 발생함
    
2. 재시작 불가능한 에러
    
    e.g.) 메세지 크기가 너무 큰 경우
    
    재시도 없이 에러 발생
    

### 비동기식

메세지를 비동기적으로 전송하고도 에러를 처리하는 경우 **콜백 지정**

```java
public interface Callback {
    void onCompletion(RecordMetadata var1, Exception var2);
}
```

```java
public class CustomKafkaCallback implements Callback {

    @Override
    public void onCompletion(RecordMetadata recordMetadata, Exception e) {
        if (e != null) {
            e.printStackTrace();
        }
    }
}
```

```java
private void sendRecord(String key, String value) {
    ProducerRecord<String, String> producerRecord = new ProducerRecord<>(topic, key, value);
    kafkaProducer.send(producerRecord, new CustomKafkaCallback());
}
```

### Producer 설정하기

설정값

- client.id 
`ProducerConfig.CLIENT_ID_CONFIG`
    
    producer와 producer 를 사용하는 app 을 구별하기 위한 논리적 식별자
    
    트러블 슈팅을 쉽게 할 수 있게 함
    
- acks
    
    임의의 쓰기 작업이 성공했다고 판별하기 위해 얼마나 많은 파티션 레플리카가 해당 레코드를 받아야 하는가
    
    default : leader 가 받은후 쓰기 작업이 성공했다고 응답
    
    - acks = 0
        
        매우 높은 처리량 필요할 때 사용 가능 / 실패시 메세지는 그대로 유실되기에 유효한 서비스만
        
    - acks = 1
        
        leader 에 crush가 난 상태에서 메세지 복제가 안된상태로 새 리더가 선출될 경우 메세지 유실이 유지될 가능성 있음
        
    - acks = all
        
        모든 `in-sync replica`에 전달된 뒤에야 성공했다는 응답을 받음
        `Note that enabling idempotence requires this config value to be 'all'. If conflicting configurations are set and idempotence is not explicitly enabled, idempotence is disabled.`
        
    
    결국은 신뢰성 - 성능 의 trade-off 이다
    
    하지만, record 가 생성되고, consumer 가 읽을때 까지의 end-to-end-latency 의 경우 세 값이 모두 같다.
    
    즉, **producer의 지연이 중요하지 않다면** ‘all’ 도 좋은 선택이 될 수 있다.(trade-off 할 값 없이 신뢰성이 좋기에)
    

```java
kafkaProps.put(ProducerConfig.CLIENT_ID_CONFIG, "kafka-producer");
kafkaProps.put(ProducerConfig.ACKS_CONFIG, "1"); // "all"
// 
```

### 메세지 전달 시간

apache kafka 2.1 기준, ProducerRecord 를 보낼 때 걸리는 구간을 2개로 나누어 처리한다.

1. send() 에 대한 비동기 호출이 이뤄진 시각 ~ 결과를 리턴할때까지 걸리는 시간
    
    send() 호출한 스레드는 블록
    
2. 비동기 호출 성공적 리턴한 시각부터 콜백이 호출될때까지 걸리는 시간

```java
max.block.ms
프로듀서가 얼마나 오랫동안 블록되는지

delivery.timeout.ms
전송 준비가 완료된 시점에서부터 브로커의 응답을 받거나 아니면 전송을 포기하게 된 시점까지의 제한시간
이 값을 제한을 걸고, retries 를 무한으로 설정하는 방법도 있음

request.timeout.ms
각각의 쓰기 요청 후 전송을 포기하기까지 대기하는 시간
* 재시도 시간, 실제 전송 이전에 소요되는 시간을 포함하지 않음

retries 재시도 횟수
retries.backoff.ms 한번 시도 후 기다리는 시간
retries=0 : 재전송 끄는 방법

linger.ms
현재 배치를 전송하기 전까지 대기하는 시간

buffer.memory
max.block.ms 동안 버퍼 메모리에 공간이 생기기를 기다리는데,
그동안 공간이 확보되지 않으면 exception 을 발생
이 exception 은 Future 객체가 아닌 send() 메서드에서 발생

compression.type
default: 압축 x
gzip : cpu/time 은 많이 사용하지만 압축률이 좋음

batch.size
각각의 배치에 사용될 메모리의 양 (byte 단위)

max.in.flight.requests.per.connection
서버로부터 응답을 받지 못한 상태에서 전송할 수 있는 최대 메세지의 수
메모리사용량 증가, 처리량 역시 증가
기본값 : 5
단일 DS 에서 카프카 설정시 2일때 처리량이 최대라고 함

max.rquest.size
전송하는 쓰기 요청의 크기 결정

receive.buffer.bytes, send.buffer.bytes
socket 이 사용하는 TCP 송수신 버퍼의 크기를 결정

enable.idempotence
producer 는 record 를 보낼 때 마다 순차적인 번호를 붙여서 보낸다
브로커가 동일한 번호를 가진 레코드를 2개 이상 받을 경우 하나만 저장
프로듀서는 별다른 문제를 발생시키지 않는 DuplicateSequenceException 를 받게 된다
prerequisite
* max.in.flight.request.per.connection <= 5
* retries >= 1
* acks = all
이 조건을 만족하지 않는다면 ConfigException 발생

```

### 순서 보장

kafka 는 **파티션내에서** 순서를 보존하게 되어있음

retries > 0, max.in.flight.requests.per.connection > 1 일 경우, 순서가 뒤집힐 가능성이 있음

두 상태에서 순서를 보장하기 위해 가장 합당한 선택은 `enable.idempotence=true` 로 설정하는 것

## Partition

key의 값이 null 인 record 가 주어진 경우 레코드는 현재 사용 가능한 토픽의 파티션 중 하나에 랜덤하게 저장

## Header

레코드는 header 를 포함할 수 있다

```java
public ProducerRecord(String topic, Integer partition, K key, V value, Iterable<Header> headers) {
    this(topic, partition, (Long)null, key, value, headers);
}

public interface Header {
    String key();

    byte[] value();
}
```

용도 중 하나는 메세지의 전달 내역을 기록

→ 데이터가 생성된 곳의 정보를 헤더에 전달해 두면 메세지를 파싱할 필요 없이 헤더에 심어진 정보만으로 메세지를 라우팅하거나 출처를 추적 가능

## Interceptor

```java
public interface ProducerInterceptor<K, V> extends Configurable, AutoCloseable {
    ProducerRecord<K, V> onSend(ProducerRecord<K, V> var1);

    void onAcknowledgement(RecordMetadata var1, Exception var2);

    void close();
}

public class LoggingProducerInterceptor
		implements ProducerInterceptor<String, String> 
{
    @Override
    public ProducerRecord<String, String> onSend(
		    ProducerRecord<String, String> producerRecord
    ) {
    //브로커로 보내기 전, 직렬화되기 직전에 호출
        return null;
    }

    @Override
    public void onAcknowledgement(
		    RecordMetadata recordMetadata, Exception e
    ) {
		// broker 가 보낸 응답을 client가 받았을 때 호출
    }

    @Override
    public void close() {
		// AutoClosable
    }

    @Override
    public void configure(Map<String, ?> map) {
		// Configurable
    }
}

```

클라이언트의 코드를 전혀 변경하지 않은 채 적용할 수 있다

```java
// 1. interceptor 컴파일해서 jar로 만든 후 classpath 에 추가
export CLASSPATH=$CLASSPATH"~./target/CountProducerInterceptor-1.0-SNAPSHOT.jar

// 2. 설정 파일 (producer.config)를 생성

// 3. 평소처럼 app 을 실행시키되, 설정 파일을 포함해 실행한다
bin/kafka-console.producer.sh \
	--broker-list localhost:9092 \
	--topic interceptor-test \
	--producer.config producer.config
```

## 쿼터, 스로틀링

브로커에 쓰기, 읽기 속도를 제한할 수 있는 기능이 있다.

quota(한도)를 설정해주면 된다

쿼터 타입

1. produce quota
2. consume quota
3. reqest quota

1, 2 는 client 가 데이터 전송/받는 속도를 초당 바이트 수 단위로 제한

요청 쿼터의 경우 broker 가 요청을 처리하는 시간 비율 단위로 제한