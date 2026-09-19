# Storage sizes are honest estimates from public PhotoKit data

Swiper never reports an exact asset byte size. PhotoKit's public API does not
expose one, and the workarounds — reading the asset's internal filename and
querying the file system with Key-Value Coding — rely on private behaviour and
are not App Store safe. Instead Swiper estimates size from pixel dimensions and
media kind using documented average bitrates, and always presents the result as
approximate.

The alternative — exact sizes via private APIs — would look more precise but
risks app review rejection and can break without warning. An honest estimate is
a deliberate trade of precision for correctness and durability. Because the
estimate is woven through the result screen and lifetime storage totals,
revisiting it later means reworking that whole surface, so it is recorded here.

The calculation is documented in code in `SwiperKit/StorageEstimate.swift`.
