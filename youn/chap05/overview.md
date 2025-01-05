# 1. Admin Client 개요
- admin client는 비동기로 작동한다.
- 따라서 해당 메서드는 클러스터 컨트롤러로 요청을 보낸 후 Future 객체를 반환한다.
- 즉 업데이트하는 동안 list topics 요청이 들어오면 업데이트가 아직 안된 브로커가 답 할 수 있다.
- 이를 최종적 일관성 (결국에는 일관성이 생기나 언제인지는 보장 못함) 이라고 한다.

### 1.1 옵션
- AdminClient 의 각 메서드들은 특정한 Option 객체를 인수로 받는다.
- 모든 AdminClient 가 가지고 있는 Option 은 timeOutMs이다.


# 2. AdminClient 사용법
- 카프카는 부트스트랩 서버 설정에 포함된 호스트명을 기준으로 연결을 검증하고 생성한다.
- 단순한 구조의 경우 문제가 없지만 특정 상황에서 문제가 생길 수 있다.

### 2.1 DNS 별칭을 사용하는 이유
- 브로커가 많은 경우 모든 브로커 전체를 가리킬 하나의 DNS 별칭을 만들 수 있다.
- 어떤 브로커든 연결되기만 하면 되기 때문이다.
- 그러나 SASL 인증을 사용하는 경우 문제가 생길 수 있다.
- all-broker-hostname.com 으로 인증을 하는데 서버 보안 주체는 broker2.hostname.com 일 수 있기 때문이다.
- 이럴 때는 client.dns.lookup=resolve_canonical_bootstrap_servers_only 설정을 해주면 된다.

### 2.2 다수의 IP 주소로 연결되는 DNS 를 사용하는 경우
- 모든 브로커를 프록시나 로드 밸런서 뒤에 숨기는 경우는 흔하다.
- 하나의 DNS가 여러 개의 IP 주소로 연결된다.
- 그런데 이 IP 주소들은 시간이 지남에 따라 변경될 수 있다.
- IP 주소가 사용불가이면 브로커는 멀쩡하게 동작하는데 연결이 안될 수 있다는 얘기이다.
- client.dns.lookup=use_all_dns_ips를 설정하면 된다.

### 2.3 request.time.out
AdminClient 의 응답을 기다릴 수 있는 시간의 최대 값

# 3. 토픽 관리 기능 예시
- admin.listTopics 를 통해 Future 로 감싸진 topic 리스트를 얻을 수 있다.
- admin.createTopic 으로 새로운 토픽 생성도 가능하다.
  - 토픽 이름 / 파티션 숫자 / 레플리카 수 등으로 인자를 받는 NewTopic 생성자를 사용한다.
- deleteTopics를 통해 삭제도 가능하다.
  - 단 해당 토픽이 비었는지 등의 방어 코드가 필요할 것이다.
- Future 의 get을 통해 블로킹할 수도 있고 KafkaFuture 를 통해 비동기로 처리하고 콜백 메서드를 사용할 수 있다.



# 4. 설정 관리
- 설정 관리는 ConfigResource 객체를 사용해서 할 수 있다.
- ConfigResource 에는 다양한 종류가 있을 수 있다. (토픽별 설정이 존재하는 것과 같이)
- describeConfigs 메서드를 통해 Config에 되어있는 정보를 확인할 수 있다.


# 5.컨슈머 그룹 관리
- 컨슈머 API를 통해 처리 지점을 돌리고 읽었던 메세지를 재처리할 수 있다.
  - 따라서 어플리케이션도 재처리 가능하게 설계를 해야한다.
- 트러블 슈팅을 할 때 AdminClient에서 지원하는 기능을 사용할 수 있다.
- admin.listConsumerGroup 을 통해 컨슈머 그룹 리스트 조회가 가능하다.
- valid().get() 과 같이 체이닝 메서드를 통해 에러 없이 리턴한 컨슈머 그룹만 조회할 수 있다.
- 가져온 Consumer 객체를 기반으로 latestOffset, partition, committedOffset 등을 조회할 수 있다.
- 카프카에서는 현재 작업이 돌아가고 있는 컨슈머 그룹에 대한 오프셋을 수정하는 것을 허용하지 않는다.
- 그래서 그룹을 수정하고 싶으면 컨슈머 그룹을 먼저 중지하고 수정을 해야한다.

# 6. 고급 어드민 작업
- topic 이름과 추가된 이후의 partition 수를 인자로 넣어서 파티션을 추가할 수 있다.
- deleteRecords 를 통해 기준으로 지정된 오프셋보다 더 오래된 레코드를 모두 삭제한다.
- admin.electLeaders 를 통해 리더를 선출할 수 있다.
  - 비동기 작업이여서 메서드가 리턴되어도 업데이트가 안되어있을 수 있다.
- 기존 레플리카 파티션을 모두 불러와서 새로운 브로커에 할당함으로 파티션 위치를 조정할 수 있다.



